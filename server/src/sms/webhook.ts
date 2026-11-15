import { randomUUID, timingSafeEqual } from 'node:crypto';
import { Router, urlencoded, type Request } from 'express';
import { FieldValue, Timestamp, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { UserDoc } from '../accounts';
import { env } from '../env';
import type { Fb } from '../firebase';
import { HttpError } from '../http';
import { CodecError, ackTag, decodePlaintext, openSms, parseSms, type AlertFields } from './codec';
import type { SmsSender } from './gateway';
import { unwrapKey } from './keystore';

const PART_WINDOW_MS = 60 * 60_000; // how long part 1 waits for part 2
// Name on a patient created from an SMS, which only carries the short ID. The phone's full record replaces it.
export const STUB_PATIENT_NAME = '(awaiting sync)';
const VISIT_TYPES = { M: 'maternal', C: 'child', L: 'malaria', N: 'nutrition' } as const;

const inbound = z.object({ from: z.string().min(1), text: z.string().min(1).max(1000) });
const delivery = z.object({ id: z.string().min(1), status: z.string().min(1) });

function secretOk(req: Request) {
  const given = Buffer.from(String(req.query.secret ?? req.get('x-webhook-secret') ?? ''));
  const want = Buffer.from(env.SMS_WEBHOOK_SECRET);
  return given.length === want.length && timingSafeEqual(given, want);
}

const pad = (n: number) => String(n).padStart(2, '0');

// The phone clock is Rwanda local time (UTC+2, no DST). Returns null for impossible dates.
export function parsePhoneTime(t: string): Date | null {
  const [yy, mo, dd, hh, mi] = [0, 2, 4, 6, 8].map((i) => Number(t.slice(i, i + 2)));
  const d = new Date(Date.UTC(2000 + yy, mo - 1, dd, hh - 2, mi));
  const local = new Date(d.getTime() + 2 * 3_600_000);
  const back = `${pad(local.getUTCFullYear() - 2000)}${pad(local.getUTCMonth() + 1)}${pad(local.getUTCDate())}${pad(local.getUTCHours())}${pad(local.getUTCMinutes())}`;
  return back === t ? d : null;
}

class Rejected extends Error {}

export function smsRouter(fb: Fb, sender: SmsSender) {
  const router = Router();
  const { fs } = fb;
  const messages = fs.collection('smsMessages');
  router.use(urlencoded({ extended: false }));
  router.use((req, _res, next) => (secretOk(req) ? next() : next(new HttpError(401, 'unauthorized'))));

  const log = (data: Record<string, unknown>) =>
    messages.add({
      deviceId: null,
      visitId: null,
      error: null,
      gatewayId: null,
      ...data,
      createdAt: FieldValue.serverTimestamp(),
    });
  const reject = (phone: string, text: string, error: string, deviceId: string | null = null) =>
    log({ direction: 'in', phone, deviceId, rawText: text, status: 'rejected', error });

  // Always answers 200 once the secret is right, so the gateway does not retry bad messages.
  router.post('/', async (req, res) => {
    const { from, text } = inbound.parse(req.body);
    const parsed = parseSms(text);
    if (!parsed) {
      await reject(from, text, 'not_healthbridge');
      return void res.json({ ok: true });
    }

    const device = (await fs.collection('devices').doc(parsed.deviceId).get()).data();
    const user = device && ((await fs.collection('users').doc(device.userId).get()).data() as UserDoc | undefined);
    const keyDoc = device && (await fs.collection('deviceKeys').doc(parsed.deviceId).get()).data();
    if (!device || device.revokedAt || !user?.active || !keyDoc) {
      await reject(from, text, 'unknown_device');
      return void res.json({ ok: true });
    }
    const deviceId = parsed.deviceId;
    const chwId = device.userId as string;
    const key = unwrapKey(keyDoc.smsKey);

    // Reassemble: a part is parked until its sibling arrives; the auth tag tells us which one matches.
    let texts = [text];
    let sibling: DocumentReference | null = null;
    if (parsed.part) {
      const prefix = `HB1 ${deviceId} ${parsed.part === 1 ? 2 : 1}/2 `;
      const parked = await messages.where('deviceId', '==', deviceId).where('status', '==', 'part').get();
      const since = Date.now() - PART_WINDOW_MS;
      const match = parked.docs.find((c) => {
        const d = c.data();
        if (!(d.rawText as string).startsWith(prefix)) return false;
        if (((d.createdAt as Timestamp | undefined)?.toMillis() ?? 0) < since) return false;
        try {
          openSms(key, [d.rawText, text]);
          return true;
        } catch {
          return false;
        }
      });
      if (!match) {
        await log({ direction: 'in', phone: from, deviceId, rawText: text, status: 'part' });
        return void res.json({ ok: true });
      }
      sibling = match.ref;
      texts = [match.data().rawText, text];
    }

    let opened: ReturnType<typeof openSms>;
    let fields: AlertFields;
    try {
      opened = openSms(key, texts);
      fields = decodePlaintext(opened.plaintext);
    } catch (e) {
      await reject(from, text, e instanceof CodecError ? e.message : 'invalid', deviceId);
      return void res.json({ ok: true });
    }
    const recordedAt = parsePhoneTime(fields.time);
    const healthCenterId = user.healthCenterId;
    if (!recordedAt || !healthCenterId) {
      await reject(from, text, recordedAt ? 'no_health_center' : 'bad_time', deviceId);
      return void res.json({ ok: true });
    }

    // The message's ID is device + nonce, so a replayed SMS collides with the first one and is refused.
    const messageRef = messages.doc(`${deviceId}_${opened.nonce.toString('hex')}`);
    const known = fields.signs.length
      ? await fs.getAll(...fields.signs.map((c) => fs.collection('dangerSigns').doc(c)))
      : [];
    let visitId: string;
    try {
      visitId = await fs.runTransaction(async (tx) => {
        if ((await tx.get(messageRef)).exists) throw new Rejected('replay');
        const patientSnap = await tx.get(fs.collection('patients').where('shortId', '==', fields.patient).limit(1));
        // The internet alert, the phone's full visit or an earlier copy of this SMS may already be here.
        const visitSnap = await tx.get(
          fs.collection('visits').where('deviceId', '==', deviceId).where('shortCode', '==', fields.shortCode).limit(1),
        );
        const id = visitSnap.empty ? randomUUID() : visitSnap.docs[0].id;
        const alertRef = fs.collection('alerts').doc(id);
        const alertExists = (await tx.get(alertRef)).exists;

        let patientId: string;
        if (!patientSnap.empty) {
          if (patientSnap.docs[0].data().chwId !== chwId) throw new Rejected('patient_mismatch');
          patientId = patientSnap.docs[0].id;
        } else {
          // The SMS only carries the short ID; this stub is replaced when the CHW's full record arrives.
          patientId = randomUUID();
          const at = Timestamp.fromDate(recordedAt);
          tx.create(fs.collection('patients').doc(patientId), {
            shortId: fields.patient,
            chwId,
            healthCenterId,
            fullName: STUB_PATIENT_NAME,
            sex: null,
            birthDate: null,
            ageEstimate: null,
            village: '',
            phone: null,
            consentAt: at,
            createdAt: at,
            updatedAt: at,
            archivedAt: null,
          });
        }

        if (visitSnap.empty) {
          tx.create(fs.collection('visits').doc(id), {
            shortCode: fields.shortCode,
            patientId,
            chwId,
            healthCenterId,
            deviceId,
            type: VISIT_TYPES[fields.type],
            answers: { signs: fields.signs, vitals: fields.vitals },
            notes: null,
            isUrgent: true,
            dangerSigns: known.filter((k) => k.exists).map((k) => k.id),
            followUpOn: null,
            recordedAt: Timestamp.fromDate(recordedAt),
            receivedAt: FieldValue.serverTimestamp(),
            source: 'sms',
            isPartial: true,
          });
        }
        if (!alertExists) {
          tx.create(alertRef, {
            visitId: id,
            chwId,
            healthCenterId,
            channel: 'sms',
            status: 'new',
            createdAt: FieldValue.serverTimestamp(),
            ackedToChwAt: null,
          });
        }
        tx.create(messageRef, {
          direction: 'in',
          phone: from,
          deviceId,
          rawText: text,
          status: 'parsed',
          error: null,
          gatewayId: null,
          visitId: id,
          createdAt: FieldValue.serverTimestamp(),
        });
        if (sibling) tx.update(sibling, { status: 'parsed', visitId: id });
        return id;
      });
    } catch (e) {
      if (!(e instanceof Rejected)) throw e;
      await reject(from, text, e.message, deviceId);
      return void res.json({ ok: true });
    }

    // The alert is already stored; a failed acknowledgement is logged, not an error for the gateway.
    const ackText = `HB OK ${fields.shortCode} ${ackTag(key, fields.shortCode)}`;
    const out = { direction: 'out', phone: from, deviceId, rawText: ackText, visitId };
    try {
      const { gatewayId } = await sender.send(from, ackText);
      await log({ ...out, status: 'sent', gatewayId });
    } catch (e) {
      await log({ ...out, status: 'failed', error: String(e).slice(0, 200) });
    }
    res.json({ ok: true });
  });

  router.post('/delivery', async (req, res) => {
    const { id, status } = delivery.parse(req.body);
    const delivered = status === 'Success';
    const snap = await messages.where('gatewayId', '==', id).where('direction', '==', 'out').limit(1).get();
    if (!snap.empty) {
      const msg = snap.docs[0];
      await msg.ref.update({ status: delivered ? 'delivered' : 'failed', error: delivered ? null : status });
      const visitId = msg.data().visitId as string | null;
      if (delivered && visitId) {
        const alert = fs.collection('alerts').doc(visitId);
        const a = (await alert.get()).data();
        if (a && !a.ackedToChwAt) await alert.update({ ackedToChwAt: FieldValue.serverTimestamp() });
      }
    }
    res.json({ ok: true });
  });

  return router;
}

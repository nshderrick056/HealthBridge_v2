import { randomUUID, timingSafeEqual } from 'node:crypto';
import { Router, urlencoded, type Request } from 'express';
import { z } from 'zod';
import type { Db } from '../db';
import { isUniqueViolation } from '../devices/routes';
import { env } from '../env';
import { HttpError } from '../http';
import { CodecError, decodePlaintext, openSms, parseSms, type AlertFields } from './codec';
import type { SmsSender } from './gateway';
import { unwrapKey } from './keystore';

const PART_WINDOW_MS = 60 * 60_000; // how long part 1 waits for part 2
// Name on a patient created from an SMS, which only carries the short ID. /sync/push replaces it.
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

export function smsRouter(db: Db, sender: SmsSender) {
  const router = Router();
  router.use(urlencoded({ extended: false }));
  router.use((req, _res, next) => (secretOk(req) ? next() : next(new HttpError(401, 'unauthorized'))));

  const reject = async (phone: string, text: string, error: string, deviceId: string | null = null) => {
    await db.sms_messages.create({
      data: { direction: 'in', phone, device_id: deviceId, raw_text: text, status: 'rejected', error },
    });
  };

  // Always answers 200 once the secret is right, so the gateway does not retry bad messages.
  router.post('/', async (req, res) => {
    const { from, text } = inbound.parse(req.body);
    const parsed = parseSms(text);
    if (!parsed) {
      await reject(from, text, 'not_healthbridge');
      return void res.json({ ok: true });
    }

    const device = await db.devices.findFirst({
      where: { id: parsed.deviceId, revoked_at: null },
      include: { user: true },
    });
    if (!device || !device.user.active) {
      await reject(from, text, 'unknown_device');
      return void res.json({ ok: true });
    }
    const key = unwrapKey(device.sms_key);

    // Reassemble: a part is parked until its sibling arrives; the auth tag tells us which one matches.
    let texts = [text];
    let sibling: { id: bigint } | null = null;
    if (parsed.part) {
      const candidates = await db.sms_messages.findMany({
        where: {
          device_id: device.id,
          status: 'part',
          created_at: { gte: new Date(Date.now() - PART_WINDOW_MS) },
          raw_text: { startsWith: `HB1 ${device.id} ${parsed.part === 1 ? 2 : 1}/2 ` },
        },
        orderBy: { created_at: 'desc' },
      });
      const match = candidates.find((c) => {
        try {
          openSms(key, [c.raw_text, text]);
          return true;
        } catch {
          return false;
        }
      });
      if (!match) {
        await db.sms_messages.create({
          data: { direction: 'in', phone: from, device_id: device.id, raw_text: text, status: 'part' },
        });
        return void res.json({ ok: true });
      }
      sibling = match;
      texts = [match.raw_text, text];
    }

    let opened: ReturnType<typeof openSms>;
    let fields: AlertFields;
    try {
      opened = openSms(key, texts);
      fields = decodePlaintext(opened.plaintext);
    } catch (e) {
      await reject(from, text, e instanceof CodecError ? e.message : 'invalid', device.id);
      return void res.json({ ok: true });
    }
    const recordedAt = parsePhoneTime(fields.time);
    const healthCenterId = device.user.health_center_id;
    if (!recordedAt || !healthCenterId) {
      await reject(from, text, recordedAt ? 'no_health_center' : 'bad_time', device.id);
      return void res.json({ ok: true });
    }

    let visitId: string;
    try {
      visitId = await db.$transaction(async (tx) => {
        // UNIQUE (device_id, nonce) is the replay check: a reused nonce aborts the whole transaction.
        await tx.sms_messages.create({
          data: {
            direction: 'in',
            phone: from,
            device_id: device.id,
            nonce: new Uint8Array(opened.nonce),
            raw_text: text,
            status: 'parsed',
          },
        });
        if (sibling) await tx.sms_messages.update({ where: { id: sibling.id }, data: { status: 'parsed' } });

        let patient = await tx.patients.findFirst({ where: { short_id: fields.patient } });
        if (patient && patient.chw_id !== device.user_id) throw new CodecError('patient_mismatch');
        // The SMS only carries the short ID. The stub is replaced when the CHW's full record syncs (slice 5).
        patient ??= await tx.patients.create({
          data: {
            id: randomUUID(),
            short_id: fields.patient,
            chw_id: device.user_id,
            full_name: STUB_PATIENT_NAME,
            village: '',
            consent_at: recordedAt,
            created_at: recordedAt,
            updated_at: recordedAt,
          },
        });

        // The internet alert or an earlier copy of this SMS may already have created the visit.
        let visit = await tx.visits.findFirst({ where: { device_id: device.id, short_code: fields.shortCode } });
        if (!visit) {
          const known = await tx.danger_signs.findMany({ where: { code: { in: fields.signs } } });
          visit = await tx.visits.create({
            data: {
              id: randomUUID(),
              short_code: fields.shortCode,
              patient_id: patient.id,
              chw_id: device.user_id,
              device_id: device.id,
              type: VISIT_TYPES[fields.type],
              answers: { signs: fields.signs, vitals: fields.vitals },
              is_urgent: true,
              recorded_at: recordedAt,
              source: 'sms',
              is_partial: true,
              visit_danger_signs: { create: known.map((k) => ({ code: k.code })) },
            },
          });
        }
        await tx.alerts.upsert({
          where: { visit_id: visit.id },
          update: {},
          create: { visit_id: visit.id, health_center_id: healthCenterId, channel: 'sms' },
        });
        return visit.id;
      });
    } catch (e) {
      if (!isUniqueViolation(e) && !(e instanceof CodecError)) throw e;
      await reject(from, text, isUniqueViolation(e) ? 'replay' : (e as CodecError).message, device.id);
      return void res.json({ ok: true });
    }

    // The alert is already stored; a failed acknowledgement is logged, not an error for the gateway.
    const ackText = `HB OK ${fields.shortCode}`;
    const out = { direction: 'out', phone: from, device_id: device.id, raw_text: ackText, visit_id: visitId };
    try {
      const { gatewayId } = await sender.send(from, ackText);
      await db.sms_messages.create({ data: { ...out, status: 'sent', gateway_id: gatewayId } });
    } catch (e) {
      await db.sms_messages.create({ data: { ...out, status: 'failed', error: String(e).slice(0, 200) } });
    }
    res.json({ ok: true });
  });

  router.post('/delivery', async (req, res) => {
    const { id, status } = delivery.parse(req.body);
    const delivered = status === 'Success';
    const msg = await db.sms_messages.findFirst({ where: { direction: 'out', gateway_id: id } });
    if (msg) {
      await db.sms_messages.update({
        where: { id: msg.id },
        data: { status: delivered ? 'delivered' : 'failed', error: delivered ? null : status },
      });
      if (delivered && msg.visit_id) {
        await db.alerts.updateMany({
          where: { visit_id: msg.visit_id, acked_to_chw_at: null },
          data: { acked_to_chw_at: new Date() },
        });
      }
    }
    res.json({ ok: true });
  });

  return router;
}

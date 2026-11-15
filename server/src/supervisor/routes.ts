// Supervisor API (PRD FR-12, FR-13, FR-15) for the web dashboard; the mobile app reads the same data from
// Firestore directly, under the security rules. Every query is scoped to the health centre in the
// caller's token, so a supervisor never sees, or learns of, another centre's cases. Status changes always
// come here (the rules forbid them from apps) so the transitions, history and CHW notice stay consistent.
// Guards sit on each route: this router is mounted at the root and must not block what it does not serve.
import { Router, type Response } from 'express';
import { FieldValue, Timestamp, type DocumentSnapshot } from 'firebase-admin/firestore';
import { z } from 'zod';
import { audit, type UserDoc } from '../accounts';
import type { Fb } from '../firebase';
import { HttpError } from '../http';
import { callerOf, requireRole, requireUser } from '../middleware/auth';
import type { SmsSender } from '../sms/gateway';
import { STUB_PATIENT_NAME } from '../sms/webhook';

const STATUSES = ['new', 'reviewed', 'escalated', 'follow_up', 'resolved'] as const;
type Status = (typeof STATUSES)[number];

// Where a case can go next. 'new' is only ever the starting state, and a resolved case stays closed.
export const TRANSITIONS: Record<Status, Status[]> = {
  new: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  reviewed: ['escalated', 'follow_up', 'resolved'],
  escalated: ['follow_up', 'resolved'],
  follow_up: ['escalated', 'resolved'],
  resolved: [],
};

const listQuery = z.object({
  // 'open' is everything not yet resolved, the inbox default.
  status: z.enum([...STATUSES, 'open']).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});
const idParam = z.string().min(1).max(100);
const patchBody = z.object({
  status: z.enum(['reviewed', 'escalated', 'follow_up', 'resolved']),
  note: z.string().trim().max(500).optional(),
});

// Status changes the CHW must act on are texted at once. Only the case code, never patient details.
const CHW_NOTICE: Partial<Record<Status, (code: string) => string>> = {
  escalated: (code) => `HealthBridge: case ${code} has been escalated by the health centre.`,
  follow_up: (code) => `HealthBridge: the health centre asks you to follow up case ${code}.`,
};

const iso = (t: unknown) => (t instanceof Timestamp ? t.toDate().toISOString() : null);
// An SMS-only case has a stub patient: name unknown and no village, until the full record arrives.
const patientName = (p: { fullName?: string } | undefined) =>
  !p || p.fullName === STUB_PATIENT_NAME ? null : (p.fullName ?? null);

export function supervisorRouter(fb: Fb, sender: SmsSender) {
  const router = Router();
  const { fs } = fb;
  const guard = [requireUser(fb), requireRole('supervisor')];

  function centreOf(res: Response) {
    const { uid, hc } = callerOf(res);
    if (!hc) throw new HttpError(403, 'no_health_center');
    return { uid, hc };
  }

  async function ownAlert(id: unknown, hc: string) {
    const snap = await fs.collection('alerts').doc(idParam.parse(id)).get();
    if (!snap.exists || snap.data()!.healthCenterId !== hc) throw new HttpError(404, 'not_found');
    return snap;
  }

  /** The alert with its visit, patient, CHW and danger-sign labels. */
  async function expand(a: DocumentSnapshot) {
    const alert = a.data()!;
    const visit = (await fs.collection('visits').doc(alert.visitId).get()).data() ?? {};
    const [patientSnap, chwSnap] = await Promise.all([
      fs.collection('patients').doc(visit.patientId ?? '-').get(),
      fs.collection('users').doc(alert.chwId).get(),
    ]);
    const signs: string[] = visit.dangerSigns ?? [];
    const labels = signs.length ? await fs.getAll(...signs.map((c) => fs.collection('dangerSigns').doc(c))) : [];
    return {
      alert,
      visit,
      patient: patientSnap.data(),
      chw: chwSnap.data() as UserDoc | undefined,
      signs: labels.map((l) => ({ code: l.id, label: (l.data()?.labelEn as string) ?? l.id })),
    };
  }

  /** Sends and logs the CHW notice. A failed send is logged, never an error: the status change stands. */
  async function notifyChw(alertId: string, status: Status) {
    const notice = CHW_NOTICE[status];
    if (!notice) return;
    const { visit, chw } = await expand(await fs.collection('alerts').doc(alertId).get());
    if (!chw) return;
    const text = notice(visit.shortCode);
    const out = { direction: 'out', phone: chw.phone, deviceId: visit.deviceId ?? null, rawText: text, visitId: alertId };
    const log = (extra: Record<string, unknown>) =>
      fs.collection('smsMessages').add({ ...out, ...extra, createdAt: FieldValue.serverTimestamp() });
    try {
      const { gatewayId } = await sender.send(chw.phone, text);
      await log({ status: 'sent', gatewayId, error: null });
    } catch (e) {
      await log({ status: 'failed', gatewayId: null, error: String(e).slice(0, 200) });
    }
  }

  router.get('/alerts', ...guard, async (req, res) => {
    const { hc } = centreOf(res);
    const { status, limit } = listQuery.parse(req.query);
    const base = fs.collection('alerts').where('healthCenterId', '==', hc);
    const query = status && status !== 'open' ? base.where('status', '==', status) : base;
    // Received time, not the phone clock, which may be wrong (App Flow §7).
    const snap = await query.orderBy('createdAt', 'desc').limit(limit).get();
    const docs = status === 'open' ? snap.docs.filter((d) => d.data().status !== 'resolved') : snap.docs;
    const counts = await Promise.all(
      STATUSES.map(async (s) => [s, (await base.where('status', '==', s).count().get()).data().count] as const),
    );

    const alerts = await Promise.all(
      docs.map(async (d) => {
        const { alert, visit, patient, chw, signs } = await expand(d);
        return {
          id: d.id,
          status: alert.status,
          channel: alert.channel,
          createdAt: iso(alert.createdAt),
          ackedToChwAt: iso(alert.ackedToChwAt),
          isPartial: !!visit.isPartial,
          visit: { id: alert.visitId, type: visit.type ?? null, recordedAt: iso(visit.recordedAt) },
          patient: { shortId: patient?.shortId ?? null, name: patientName(patient) },
          chw: { id: alert.chwId, name: chw?.fullName ?? null },
          village: patient?.village || chw?.village || null,
          dangerSigns: signs.map((s) => s.label),
        };
      }),
    );
    res.json({ alerts, counts: Object.fromEntries(counts) });
  });

  router.get('/alerts/:id', ...guard, async (req, res) => {
    const { hc } = centreOf(res);
    const snap = await ownAlert(req.params.id, hc);
    const { alert, visit, patient, chw, signs } = await expand(snap);
    const events = await snap.ref.collection('events').orderBy('createdAt', 'asc').get();
    const actors = new Map<string, string>();
    for (const e of events.docs) {
      const actorId = e.data().actorId as string | null;
      if (actorId && !actors.has(actorId)) {
        actors.set(actorId, ((await fs.collection('users').doc(actorId).get()).data()?.fullName as string) ?? '');
      }
    }

    res.json({
      id: snap.id,
      status: alert.status,
      channel: alert.channel,
      createdAt: iso(alert.createdAt),
      ackedToChwAt: iso(alert.ackedToChwAt),
      next: TRANSITIONS[alert.status as Status],
      visit: {
        id: alert.visitId,
        shortCode: visit.shortCode ?? null,
        type: visit.type ?? null,
        answers: visit.answers ?? {},
        notes: visit.notes ?? null,
        followUpOn: iso(visit.followUpOn),
        recordedAt: iso(visit.recordedAt),
        receivedAt: iso(visit.receivedAt),
        source: visit.source ?? null,
        isPartial: !!visit.isPartial,
      },
      // Minimum necessary for triage: no patient phone number.
      patient: {
        shortId: patient?.shortId ?? null,
        name: patientName(patient),
        sex: patient?.sex ?? null,
        birthDate: iso(patient?.birthDate),
        ageEstimate: patient?.ageEstimate ?? null,
        village: patient?.village || chw?.village || null,
      },
      chw: { id: alert.chwId, name: chw?.fullName ?? null, phone: chw?.phone ?? null },
      dangerSigns: signs,
      events: events.docs.map((e) => {
        const ev = e.data();
        return {
          id: e.id,
          fromStatus: ev.fromStatus ?? null,
          toStatus: ev.toStatus,
          note: ev.note ?? null,
          actor: ev.actorId ? (actors.get(ev.actorId) ?? null) : null,
          createdAt: iso(ev.createdAt),
        };
      }),
    });
  });

  router.patch('/alerts/:id', ...guard, async (req, res) => {
    const { uid, hc } = centreOf(res);
    const ref = (await ownAlert(req.params.id, hc)).ref;
    const { status, note } = patchBody.parse(req.body);

    const eventRef = ref.collection('events').doc();
    const from = await fs.runTransaction(async (tx) => {
      // Re-read inside the transaction: if another supervisor got there first, the transition is re-checked.
      const current = (await tx.get(ref)).data()!.status as Status;
      if (!TRANSITIONS[current].includes(status)) throw new HttpError(409, 'invalid_transition');
      tx.update(ref, { status });
      tx.create(eventRef, {
        actorId: uid,
        fromStatus: current,
        toStatus: status,
        note: note || null,
        createdAt: FieldValue.serverTimestamp(),
      });
      return current;
    });
    await audit(fb, uid, `alert.${status}`, 'alerts', ref.id);
    await notifyChw(ref.id, status);
    const event = (await eventRef.get()).data()!;

    res.json({
      id: ref.id,
      status,
      next: TRANSITIONS[status],
      event: { id: eventRef.id, fromStatus: from, toStatus: status, note: event.note, createdAt: iso(event.createdAt) },
    });
  });

  router.get('/chws', ...guard, async (_req, res) => {
    const { hc } = centreOf(res);
    const snap = await fs
      .collection('users')
      .where('healthCenterId', '==', hc)
      .where('role', '==', 'chw')
      .where('active', '==', true)
      .get();
    const chws = await Promise.all(
      snap.docs.map(async (d) => {
        const u = d.data();
        const devices = await fs.collection('devices').where('userId', '==', d.id).get();
        const last = Math.max(
          0,
          ...devices.docs
            .filter((x) => !x.data().revokedAt)
            .map((x) => (x.data().lastSyncAt as Timestamp | null)?.toMillis() ?? 0),
        );
        // Pending = urgent cases that reached us only by SMS and still wait for the phone's full record.
        const pending = await fs.collection('visits').where('chwId', '==', d.id).where('isPartial', '==', true).count().get();
        return {
          id: d.id,
          name: u.fullName as string,
          chwRole: u.chwRole ?? null,
          phone: u.phone,
          village: u.village ?? null,
          lastSyncAt: last ? new Date(last).toISOString() : null,
          pendingCount: pending.data().count,
        };
      }),
    );
    chws.sort((a, b) => a.name.localeCompare(b.name));
    res.json({ chws });
  });

  return router;
}

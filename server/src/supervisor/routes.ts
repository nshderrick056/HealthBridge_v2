// Supervisor dashboard API (PRD FR-12, FR-13, FR-15). Every query is scoped to the health centre in
// the access token, so a supervisor never sees, or learns of, another centre's cases.
// Guards sit on each route, not router.use(): this router is mounted at the root next to the CHW
// `POST /alerts` router, and must not block requests it does not serve.
import { Router, type Request } from 'express';
import { z } from 'zod';
import type { AccessClaims } from '../auth/tokens';
import type { Db } from '../db';
import type { alert_status } from '../generated/prisma/client';
import { HttpError } from '../http';
import { requireAuth, requireRole } from '../middleware/auth';
import { STUB_PATIENT_NAME } from '../sms/webhook';

const STATUSES = ['new', 'reviewed', 'escalated', 'follow_up', 'resolved'] as const;

// Where a case can go next. 'new' is only ever the starting state, and a resolved case stays closed.
export const TRANSITIONS: Record<alert_status, alert_status[]> = {
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
const idParams = z.object({ id: z.uuid() });
const patchBody = z.object({
  status: z.enum(['reviewed', 'escalated', 'follow_up', 'resolved']),
  note: z.string().trim().max(500).optional(),
});

const guard = [requireAuth, requireRole('supervisor')];

function centreOf(res: { locals: Record<string, unknown> }) {
  const { sub, hc } = res.locals.auth as AccessClaims;
  if (!hc) throw new HttpError(403, 'no_health_center');
  return { sub, hc };
}

const iso = (d: Date | null) => d?.toISOString() ?? null;
// An SMS-only case has a stub patient: name unknown and no village, until the full record syncs.
const patientName = (p: { full_name: string }) => (p.full_name === STUB_PATIENT_NAME ? null : p.full_name);

export function supervisorRouter(db: Db) {
  const router = Router();

  const findAlert = async (req: Request, hc: string) => {
    const { id } = idParams.parse(req.params);
    const alert = await db.alerts.findFirst({ where: { id, health_center_id: hc }, select: { id: true, status: true } });
    if (!alert) throw new HttpError(404, 'not_found');
    return alert;
  };

  router.get('/alerts', ...guard, async (req, res) => {
    const { hc } = centreOf(res);
    const { status, limit } = listQuery.parse(req.query);
    const [alerts, counts] = await Promise.all([
      db.alerts.findMany({
        where: {
          health_center_id: hc,
          ...(status === 'open' ? { status: { not: 'resolved' } } : status ? { status } : {}),
        },
        // Received time, not the phone clock, which may be wrong (App Flow §7).
        orderBy: { created_at: 'desc' },
        take: limit,
        include: {
          visit: {
            include: {
              patient: { select: { short_id: true, full_name: true, village: true } },
              chw: { select: { id: true, full_name: true, village: true } },
              visit_danger_signs: { include: { danger_sign: { select: { label_en: true } } } },
            },
          },
        },
      }),
      db.alerts.groupBy({ by: ['status'], where: { health_center_id: hc }, _count: { _all: true } }),
    ]);

    res.json({
      alerts: alerts.map(({ visit, ...a }) => ({
        id: a.id,
        status: a.status,
        channel: a.channel,
        createdAt: iso(a.created_at),
        ackedToChwAt: iso(a.acked_to_chw_at),
        isPartial: visit.is_partial,
        visit: { id: visit.id, type: visit.type, recordedAt: iso(visit.recorded_at) },
        patient: { shortId: visit.patient.short_id, name: patientName(visit.patient) },
        chw: { id: visit.chw.id, name: visit.chw.full_name },
        village: visit.patient.village || visit.chw.village,
        dangerSigns: visit.visit_danger_signs.map((s) => s.danger_sign.label_en),
      })),
      counts: Object.fromEntries(STATUSES.map((s) => [s, counts.find((c) => c.status === s)?._count._all ?? 0])),
    });
  });

  router.get('/alerts/:id', ...guard, async (req, res) => {
    const { hc } = centreOf(res);
    const { id } = await findAlert(req, hc);
    const a = await db.alerts.findUniqueOrThrow({
      where: { id },
      include: {
        visit: {
          include: {
            patient: true,
            chw: { select: { id: true, full_name: true, phone: true, village: true } },
            visit_danger_signs: { include: { danger_sign: true } },
          },
        },
        events: { orderBy: { id: 'asc' }, include: { actor: { select: { full_name: true } } } },
      },
    });
    const { visit } = a;
    const { patient } = visit;

    res.json({
      id: a.id,
      status: a.status,
      channel: a.channel,
      createdAt: iso(a.created_at),
      ackedToChwAt: iso(a.acked_to_chw_at),
      next: TRANSITIONS[a.status],
      visit: {
        id: visit.id,
        shortCode: visit.short_code,
        type: visit.type,
        answers: visit.answers,
        notes: visit.notes,
        followUpOn: iso(visit.follow_up_on),
        recordedAt: iso(visit.recorded_at),
        receivedAt: iso(visit.received_at),
        source: visit.source,
        isPartial: visit.is_partial,
      },
      // Minimum necessary for triage: no patient phone number.
      patient: {
        shortId: patient.short_id,
        name: patientName(patient),
        sex: patient.sex,
        birthDate: iso(patient.birth_date),
        ageEstimate: patient.age_estimate,
        village: patient.village || visit.chw.village,
      },
      chw: { id: visit.chw.id, name: visit.chw.full_name, phone: visit.chw.phone },
      dangerSigns: visit.visit_danger_signs.map(({ danger_sign: d }) => ({ code: d.code, label: d.label_en })),
      events: a.events.map((e) => ({
        id: e.id.toString(),
        fromStatus: e.from_status,
        toStatus: e.to_status,
        note: e.note,
        actor: e.actor?.full_name ?? null,
        createdAt: iso(e.created_at),
      })),
    });
  });

  router.patch('/alerts/:id', ...guard, async (req, res) => {
    const { sub, hc } = centreOf(res);
    const alert = await findAlert(req, hc);
    const { status, note } = patchBody.parse(req.body);
    if (!TRANSITIONS[alert.status].includes(status)) throw new HttpError(409, 'invalid_transition');

    const event = await db.$transaction(async (tx) => {
      // Only moves from the status we checked: if another supervisor got there first, nothing changes.
      const { count } = await tx.alerts.updateMany({
        where: { id: alert.id, health_center_id: hc, status: alert.status },
        data: { status },
      });
      if (count === 0) throw new HttpError(409, 'status_changed');
      await tx.audit_log.create({
        data: { actor_id: sub, action: `alert.${status}`, entity: 'alerts', entity_id: alert.id },
      });
      return tx.alert_events.create({
        data: { alert_id: alert.id, actor_id: sub, from_status: alert.status, to_status: status, note: note || null },
      });
    });

    res.json({
      id: alert.id,
      status,
      next: TRANSITIONS[status],
      event: {
        id: event.id.toString(),
        fromStatus: event.from_status,
        toStatus: event.to_status,
        note: event.note,
        createdAt: iso(event.created_at),
      },
    });
  });

  router.get('/chws', ...guard, async (_req, res) => {
    const { hc } = centreOf(res);
    const chws = await db.users.findMany({
      where: { role: 'chw', health_center_id: hc, active: true },
      orderBy: { full_name: 'asc' },
      select: {
        id: true,
        full_name: true,
        chw_role: true,
        phone: true,
        village: true,
        devices: { where: { revoked_at: null }, select: { last_sync_at: true } },
      },
    });
    // Pending = urgent cases that reached us only by SMS and still wait for the phone's full record.
    // The phone's own outbox is invisible to the server until it syncs.
    const pending = await db.visits.groupBy({
      by: ['chw_id'],
      where: { chw_id: { in: chws.map((c) => c.id) }, is_partial: true },
      _count: { _all: true },
    });

    res.json({
      chws: chws.map((c) => {
        const syncs = c.devices.map((d) => d.last_sync_at?.getTime() ?? 0);
        const last = Math.max(0, ...syncs);
        return {
          id: c.id,
          name: c.full_name,
          chwRole: c.chw_role,
          phone: c.phone,
          village: c.village,
          lastSyncAt: last ? new Date(last).toISOString() : null,
          pendingCount: pending.find((p) => p.chw_id === c.id)?._count._all ?? 0,
        };
      }),
    });
  });

  return router;
}

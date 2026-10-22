// Offline sync (TRD §4). The phone pushes its outbox in order, in batches of up to 50, then pulls.
// Conflicts: the server owns alert status, the phone owns visit content, and patient details are
// last-write-wins by the phone's updated_at, with an audit_log entry.
import { Router } from 'express';
import { z, ZodError } from 'zod';
import type { AccessClaims } from '../auth/tokens';
import type { Db } from '../db';
import type { Prisma } from '../generated/prisma/client';
import { HttpError } from '../http';
import { requireAuth, requireRole } from '../middleware/auth';
import { STUB_PATIENT_NAME } from '../sms/webhook';

type Tx = Prisma.TransactionClient;

const date = z.coerce.date();
const patientPayload = z.object({
  id: z.uuid(),
  short_id: z.string().regex(/^[A-Z0-9]{2,10}$/),
  full_name: z.string().trim().min(1).max(200),
  sex: z.enum(['F', 'M']).nullable(),
  birth_date: date.nullable(),
  age_estimate: z.number().int().min(0).max(130).nullable(),
  village: z.string().max(200),
  phone: z.string().max(30).nullable(),
  consent_at: date,
  created_at: date,
  updated_at: date,
});
const visitPayload = z
  .object({
    id: z.uuid(),
    short_code: z.string().regex(/^[0-9a-f]{8}$/),
    patient_id: z.uuid(),
    type: z.enum(['maternal', 'child', 'malaria', 'nutrition']),
    answers: z.record(z.string(), z.unknown()),
    notes: z.string().max(5000).nullable(),
    is_urgent: z.boolean(),
    follow_up_on: date.nullable(),
    recorded_at: date,
    danger_signs: z.array(z.string().regex(/^[A-Z]{2}$/)).max(30),
  })
  .refine((v) => v.id.startsWith(v.short_code), 'short_code must be the first 8 hex of id');

const pushBody = z.object({
  deviceId: z.string().min(1).max(20),
  changes: z
    .array(
      z.object({
        seq: z.number().int(),
        entity: z.enum(['patient', 'visit']),
        op: z.enum(['upsert', 'delete']),
        payload: z.unknown(),
      }),
    )
    .max(50),
});
const pullQuery = z.object({ since: date.optional(), deviceId: z.string().max(20).optional() });

/** A change the server will never accept as sent; the phone marks it failed instead of retrying blindly. */
class Rejected extends Error {}

type Ctx = { chw: string; deviceId: string; healthCenterId: string | null };

async function upsertPatient(tx: Tx, ctx: Ctx, raw: unknown) {
  const p = patientPayload.parse(raw);
  const fields = {
    short_id: p.short_id,
    full_name: p.full_name,
    sex: p.sex,
    birth_date: p.birth_date,
    age_estimate: p.age_estimate,
    village: p.village,
    phone: p.phone,
    consent_at: p.consent_at,
    updated_at: p.updated_at,
  };
  const audit = (action: string) =>
    tx.audit_log.create({ data: { actor_id: ctx.chw, action, entity: 'patients', entity_id: p.id } });

  const existing = await tx.patients.findUnique({ where: { id: p.id } });
  if (existing) {
    if (existing.chw_id !== ctx.chw) throw new Rejected('not_your_patient');
    if (p.updated_at > existing.updated_at) {
      await tx.patients.update({ where: { id: p.id }, data: fields });
      await audit('patient.update');
    }
    return;
  }

  // An urgent SMS may have created a stub under this short ID; the real record takes its place.
  const stub = await tx.patients.findUnique({ where: { short_id: p.short_id } });
  if (stub && (stub.chw_id !== ctx.chw || stub.full_name !== STUB_PATIENT_NAME)) {
    throw new Rejected('short_id_taken');
  }
  if (stub) {
    await tx.patients.update({ where: { id: stub.id }, data: { short_id: `${p.short_id}~${stub.id.slice(0, 8)}` } });
  }
  await tx.patients.create({ data: { ...fields, id: p.id, chw_id: ctx.chw, created_at: p.created_at } });
  if (stub) {
    await tx.visits.updateMany({ where: { patient_id: stub.id }, data: { patient_id: p.id } });
    await tx.patients.delete({ where: { id: stub.id } });
  }
  await audit('patient.create');
}

async function upsertVisit(tx: Tx, ctx: Ctx, raw: unknown) {
  const v = visitPayload.parse(raw);
  const patient = await tx.patients.findUnique({ where: { id: v.patient_id } });
  if (!patient || patient.chw_id !== ctx.chw) throw new Rejected('unknown_patient');

  const content = {
    patient_id: v.patient_id,
    type: v.type,
    answers: v.answers as Prisma.InputJsonValue,
    notes: v.notes,
    is_urgent: v.is_urgent,
    follow_up_on: v.follow_up_on,
    recorded_at: v.recorded_at,
    source: 'sync',
    is_partial: false,
  };
  const known = await tx.danger_signs.findMany({ where: { code: { in: v.danger_signs } } });
  const signs = known.map((k) => ({ visit_id: v.id, code: k.code }));

  const existing = await tx.visits.findUnique({ where: { id: v.id } });
  if (existing) {
    if (existing.chw_id !== ctx.chw) throw new Rejected('not_your_visit');
    await tx.visits.update({ where: { id: v.id }, data: content });
    await tx.visit_danger_signs.deleteMany({ where: { visit_id: v.id } });
  } else {
    // FR-14: the SMS made a partial visit under this device + short code. The full record replaces
    // it and keeps its alert and SMS log, so the supervisor sees one case, not two.
    const partial = await tx.visits.findFirst({ where: { device_id: ctx.deviceId, short_code: v.short_code } });
    if (partial && !partial.is_partial) throw new Rejected('short_code_taken');
    if (partial) {
      await tx.visits.update({ where: { id: partial.id }, data: { short_code: `${v.short_code}~sms` } });
    }
    await tx.visits.create({
      data: { ...content, id: v.id, short_code: v.short_code, chw_id: ctx.chw, device_id: ctx.deviceId },
    });
    if (partial) {
      await tx.alerts.updateMany({ where: { visit_id: partial.id }, data: { visit_id: v.id } });
      await tx.sms_messages.updateMany({ where: { visit_id: partial.id }, data: { visit_id: v.id } });
      await tx.visits.delete({ where: { id: partial.id } });
    }
  }
  if (signs.length) await tx.visit_danger_signs.createMany({ data: signs });

  // An urgent visit that reaches the server only by sync still needs to reach the supervisor.
  if (v.is_urgent && ctx.healthCenterId) {
    await tx.alerts.upsert({
      where: { visit_id: v.id },
      update: {},
      create: { visit_id: v.id, health_center_id: ctx.healthCenterId, channel: 'internet' },
    });
  }
}

const iso = (d: Date | null) => d?.toISOString() ?? null;

export function syncRouter(db: Db) {
  const router = Router();
  router.use(requireAuth, requireRole('chw'));

  async function context(sub: string, deviceId: string): Promise<Ctx> {
    const device = await db.devices.findFirst({
      where: { id: deviceId, user_id: sub, revoked_at: null },
      include: { user: true },
    });
    if (!device || !device.user.active) throw new HttpError(403, 'unknown_device');
    return { chw: sub, deviceId, healthCenterId: device.user.health_center_id };
  }

  // Each change commits on its own, in order. A transient error fails the request so the phone retries
  // the batch; already-applied changes are idempotent by UUID.
  router.post('/push', async (req, res) => {
    const { deviceId, changes } = pushBody.parse(req.body);
    const { sub } = res.locals.auth as AccessClaims;
    const ctx = await context(sub, deviceId);

    const results: { seq: number; ok: boolean; error?: string }[] = [];
    for (const c of changes) {
      try {
        if (c.op !== 'upsert') throw new Rejected('unsupported_op');
        await db.$transaction((tx) =>
          c.entity === 'patient' ? upsertPatient(tx, ctx, c.payload) : upsertVisit(tx, ctx, c.payload),
        );
        results.push({ seq: c.seq, ok: true });
      } catch (e) {
        if (e instanceof Rejected) results.push({ seq: c.seq, ok: false, error: e.message });
        else if (e instanceof ZodError) results.push({ seq: c.seq, ok: false, error: 'invalid_payload' });
        else throw e;
      }
    }
    await db.devices.update({ where: { id: deviceId }, data: { last_sync_at: new Date() } });
    res.json({ results });
  });

  router.get('/pull', async (req, res) => {
    const { since, deviceId } = pullQuery.parse(req.query);
    const { sub } = res.locals.auth as AccessClaims;
    if (deviceId) await context(sub, deviceId);
    // Taken before reading, so a change made during this request is picked up next time, not lost.
    const serverTime = new Date();
    const after = since ?? new Date(0);

    // shortcut: patients carry only the phone's clock, so all of this CHW's patients come back each
    // time (tens to hundreds of rows); add a server-side changed_at column if that grows.
    const [patients, alerts, dangerSigns] = await Promise.all([
      db.patients.findMany({ where: { chw_id: sub, NOT: { full_name: STUB_PATIENT_NAME } } }),
      db.alerts.findMany({
        where: {
          visit: { chw_id: sub },
          OR: [
            { created_at: { gt: after } },
            { acked_to_chw_at: { gt: after } },
            { events: { some: { created_at: { gt: after } } } },
          ],
        },
      }),
      db.danger_signs.findMany(),
    ]);
    if (deviceId) await db.devices.update({ where: { id: deviceId }, data: { last_sync_at: serverTime } });

    res.json({
      serverTime: serverTime.toISOString(),
      patients: patients.map((p) => ({
        id: p.id,
        short_id: p.short_id,
        full_name: p.full_name,
        sex: p.sex,
        birth_date: iso(p.birth_date),
        age_estimate: p.age_estimate,
        village: p.village,
        phone: p.phone,
        consent_at: iso(p.consent_at),
        created_at: iso(p.created_at),
        updated_at: iso(p.updated_at),
      })),
      alerts: alerts.map((a) => ({
        visit_id: a.visit_id,
        status: a.status,
        acked_to_chw_at: iso(a.acked_to_chw_at),
      })),
      dangerSigns: dangerSigns.map((d) => ({
        code: d.code,
        visit_type: d.visit_type,
        label_en: d.label_en,
        label_rw: d.label_rw,
      })),
    });
  });

  return router;
}

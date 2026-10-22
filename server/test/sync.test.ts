import { randomInt, randomUUID } from 'node:crypto';
import type express from 'express';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { signAccess } from '../src/auth/tokens';
import { createPrisma, type Db } from '../src/db';
import { STUB_PATIENT_NAME } from '../src/sms/webhook';

// Runs against a real Postgres (CI service, or the dev DB from .env). Every row it creates hangs off
// its own health centre, CHWs and devices, and is deleted afterwards.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('sync against Postgres', () => {
  let db: Db;
  let app: express.Express;
  const tag = randomInt(1_000_000).toString().padStart(6, '0');
  const hc = randomUUID();
  const chw = randomUUID();
  const other = randomUUID();
  const deviceId = `T${tag}`;
  const otherDevice = `U${tag}`;
  const now = new Date('2026-10-06T19:14:00Z');

  const token = (sub = chw, role: 'chw' | 'supervisor' = 'chw') => `Bearer ${signAccess({ sub, role, hc })}`;
  const patient = (over: Record<string, unknown> = {}) => {
    const id = randomUUID();
    return {
      id,
      short_id: `P${id.slice(0, 6).toUpperCase()}`,
      full_name: 'Uwase Marie',
      sex: 'F',
      birth_date: null,
      age_estimate: 32,
      village: 'Nyamata',
      phone: null,
      consent_at: now.toISOString(),
      created_at: now.toISOString(),
      updated_at: now.toISOString(),
      ...over,
    };
  };
  const visit = (patientId: string, over: Record<string, unknown> = {}) => {
    const id = randomUUID();
    return {
      id,
      short_code: id.slice(0, 8),
      patient_id: patientId,
      type: 'maternal',
      answers: { general_condition: 'Stable' },
      notes: null,
      is_urgent: false,
      follow_up_on: null,
      recorded_at: now.toISOString(),
      danger_signs: [] as string[],
      ...over,
    };
  };
  const change = (seq: number, entity: 'patient' | 'visit', payload: unknown) => ({ seq, entity, op: 'upsert', payload });
  const push = (changes: unknown[], device = deviceId, auth = token()) =>
    request(app).post('/sync/push').set('authorization', auth).send({ deviceId: device, changes });

  beforeAll(async () => {
    db = createPrisma(url);
    app = createApp({ db, sender: { send: async () => ({ gatewayId: null }) } });
    await db.health_centers.create({ data: { id: hc, name: 'Sync test centre', district: 'Test', sector: 'Test' } });
    for (const [id, phone, device] of [
      [chw, `+2507${tag}91`, deviceId],
      [other, `+2507${tag}92`, otherDevice],
    ]) {
      await db.users.create({
        data: { id, role: 'chw', full_name: 'Sync Test CHW', phone, secret_hash: 'x', health_center_id: hc },
      });
      await db.devices.create({ data: { id: device, user_id: id, sms_key: new Uint8Array(60) } });
    }
    await db.danger_signs.upsert({
      where: { code: 'HB' },
      update: {},
      create: { code: 'HB', visit_type: 'maternal', label_en: 'Heavy bleeding', label_rw: '' },
    });
  });

  afterAll(async () => {
    if (!db) return;
    const users = [chw, other];
    await db.alert_events.deleteMany({ where: { alert: { health_center_id: hc } } });
    await db.alerts.deleteMany({ where: { health_center_id: hc } });
    await db.sms_messages.deleteMany({ where: { device_id: { in: [deviceId, otherDevice] } } });
    await db.visits.deleteMany({ where: { chw_id: { in: users } } }); // cascades visit_danger_signs
    await db.audit_log.deleteMany({ where: { actor_id: { in: users } } });
    await db.patients.deleteMany({ where: { chw_id: { in: users } } });
    await db.devices.deleteMany({ where: { user_id: { in: users } } });
    await db.users.deleteMany({ where: { id: { in: users } } });
    await db.health_centers.delete({ where: { id: hc } });
    await db.$disconnect();
  });

  it('pushing the same batch twice stores one patient and one visit', async () => {
    const p = patient();
    const v = visit(p.id);
    const batch = [change(1, 'patient', p), change(2, 'visit', v)];

    const first = await push(batch).expect(200);
    expect(first.body.results).toEqual([
      { seq: 1, ok: true },
      { seq: 2, ok: true },
    ]);
    await push(batch).expect(200);

    expect(await db.patients.count({ where: { id: p.id } })).toBe(1);
    const visits = await db.visits.findMany({ where: { patient_id: p.id } });
    expect(visits).toHaveLength(1);
    expect(visits[0]).toMatchObject({ id: v.id, source: 'sync', is_partial: false, device_id: deviceId });
    expect((await db.devices.findUnique({ where: { id: deviceId } }))?.last_sync_at).toBeInstanceOf(Date);
  });

  it('patients are last-write-wins by updated_at, with an audit entry', async () => {
    const p = patient();
    await push([change(1, 'patient', p)]).expect(200);

    const older = { ...p, full_name: 'Stale Name', updated_at: new Date(now.getTime() - 60_000).toISOString() };
    await push([change(2, 'patient', older)]).expect(200);
    expect((await db.patients.findUnique({ where: { id: p.id } }))?.full_name).toBe('Uwase Marie');

    const newer = { ...p, full_name: 'Uwase Marie-Claire', updated_at: new Date(now.getTime() + 60_000).toISOString() };
    await push([change(3, 'patient', newer)]).expect(200);
    expect((await db.patients.findUnique({ where: { id: p.id } }))?.full_name).toBe('Uwase Marie-Claire');

    const audit = await db.audit_log.findMany({ where: { entity_id: p.id }, orderBy: { id: 'asc' } });
    expect(audit.map((a) => a.action)).toEqual(['patient.create', 'patient.update']);
  });

  it('a full record merges into the partial case an SMS created (FR-14)', async () => {
    const p = patient();
    const v = visit(p.id, { is_urgent: true, danger_signs: ['HB'] });
    // What /webhooks/sms leaves behind: a stub patient, a partial urgent visit and its SMS alert.
    const stubId = randomUUID();
    const partialId = randomUUID();
    await db.patients.create({
      data: {
        id: stubId,
        short_id: p.short_id,
        chw_id: chw,
        full_name: STUB_PATIENT_NAME,
        village: '',
        consent_at: now,
        created_at: now,
        updated_at: now,
      },
    });
    await db.visits.create({
      data: {
        id: partialId,
        short_code: v.short_code,
        patient_id: stubId,
        chw_id: chw,
        device_id: deviceId,
        type: 'maternal',
        is_urgent: true,
        recorded_at: now,
        source: 'sms',
        is_partial: true,
      },
    });
    const alert = await db.alerts.create({ data: { visit_id: partialId, health_center_id: hc, channel: 'sms' } });

    const res = await push([change(1, 'patient', p), change(2, 'visit', v)]).expect(200);
    expect(res.body.results.every((r: { ok: boolean }) => r.ok)).toBe(true);

    expect(await db.patients.findUnique({ where: { id: stubId } })).toBeNull();
    const cases = await db.visits.findMany({ where: { device_id: deviceId, short_code: { startsWith: v.short_code } } });
    expect(cases).toHaveLength(1);
    expect(cases[0]).toMatchObject({ id: v.id, patient_id: p.id, is_partial: false, source: 'sync' });
    expect(await db.alerts.findUnique({ where: { id: alert.id } })).toMatchObject({ visit_id: v.id, channel: 'sms' });
    expect(await db.visit_danger_signs.findMany({ where: { visit_id: v.id } })).toEqual([{ visit_id: v.id, code: 'HB' }]);
  });

  it('an urgent visit that arrives only by sync raises an internet alert', async () => {
    const p = patient();
    const v = visit(p.id, { is_urgent: true, danger_signs: ['HB'] });
    await push([change(1, 'patient', p), change(2, 'visit', v)]).expect(200);
    expect(await db.alerts.findUnique({ where: { visit_id: v.id } })).toMatchObject({
      channel: 'internet',
      health_center_id: hc,
      status: 'new',
    });
  });

  it('rejects bad or foreign changes one by one and still applies the rest', async () => {
    const foreign = patient();
    await push([change(1, 'patient', foreign)], otherDevice, token(other)).expect(200);

    const good = patient();
    const res = await push([
      change(1, 'patient', patient({ short_id: 'not valid' })),
      change(2, 'visit', visit(foreign.id)),
      change(3, 'patient', { ...foreign, full_name: 'Hijack', updated_at: new Date(now.getTime() + 1e6).toISOString() }),
      change(4, 'patient', good),
    ]).expect(200);

    expect(res.body.results).toEqual([
      { seq: 1, ok: false, error: 'invalid_payload' },
      { seq: 2, ok: false, error: 'unknown_patient' },
      { seq: 3, ok: false, error: 'not_your_patient' },
      { seq: 4, ok: true },
    ]);
    expect((await db.patients.findUnique({ where: { id: foreign.id } }))?.full_name).toBe('Uwase Marie');
  });

  it("refuses another CHW's device and non-CHW roles", async () => {
    await push([], otherDevice).expect(403);
    await push([], deviceId, token(chw, 'supervisor')).expect(403);
    await request(app).post('/sync/push').send({ deviceId, changes: [] }).expect(401);
  });

  it('pull returns patients, new alerts and danger signs, and `since` skips alerts already seen', async () => {
    const p = patient();
    const v = visit(p.id, { is_urgent: true });
    await push([change(1, 'patient', p), change(2, 'visit', v)]).expect(200);

    const first = await request(app)
      .get(`/sync/pull?deviceId=${deviceId}`)
      .set('authorization', token())
      .expect(200);
    expect(first.body.patients.map((x: { id: string }) => x.id)).toContain(p.id);
    expect(first.body.patients.every((x: { full_name: string }) => x.full_name !== STUB_PATIENT_NAME)).toBe(true);
    expect(first.body.alerts).toContainEqual({ visit_id: v.id, status: 'new', acked_to_chw_at: null });
    expect(first.body.dangerSigns).toContainEqual(expect.objectContaining({ code: 'HB', visit_type: 'maternal' }));

    const again = await request(app)
      .get(`/sync/pull?since=${encodeURIComponent(first.body.serverTime)}`)
      .set('authorization', token())
      .expect(200);
    expect(again.body.alerts.map((a: { visit_id: string }) => a.visit_id)).not.toContain(v.id);
  });
});

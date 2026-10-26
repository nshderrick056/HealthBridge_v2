import { randomInt, randomUUID } from 'node:crypto';
import type express from 'express';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { signAccess } from '../src/auth/tokens';
import { createPrisma, type Db } from '../src/db';
import { STUB_PATIENT_NAME } from '../src/sms/webhook';

// Runs against a real Postgres, like sync.test.ts. Everything hangs off its own centre, CHWs and devices.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('POST /alerts against Postgres', () => {
  let db: Db;
  let app: express.Express;
  const tag = randomInt(1_000_000).toString().padStart(6, '0');
  const hc = randomUUID();
  const chw = randomUUID();
  const other = randomUUID();
  const loner = randomUUID(); // a CHW with no health centre
  const deviceId = `A${tag}`;
  const otherDevice = `B${tag}`;
  const lonerDevice = `C${tag}`;
  const now = new Date('2026-10-06T19:14:00Z');

  const token = (sub = chw, role: 'chw' | 'supervisor' = 'chw') => `Bearer ${signAccess({ sub, role, hc })}`;
  const patient = () => {
    const id = randomUUID();
    return {
      id,
      short_id: `P${id.slice(0, 6).toUpperCase()}`,
      full_name: 'Mukamana Alice',
      sex: 'F',
      birth_date: null,
      age_estimate: 27,
      village: 'Gashora',
      phone: null,
      consent_at: now.toISOString(),
      created_at: now.toISOString(),
      updated_at: now.toISOString(),
    };
  };
  const visit = (patientId: string, over: Record<string, unknown> = {}) => {
    const id = randomUUID();
    return {
      id,
      short_code: id.slice(0, 8),
      patient_id: patientId,
      type: 'maternal',
      answers: { general_condition: 'Unstable', temperature: 38.9 },
      notes: null,
      is_urgent: true,
      follow_up_on: null,
      recorded_at: now.toISOString(),
      danger_signs: ['HB'],
      ...over,
    };
  };
  const post = (body: Record<string, unknown>, auth = token()) =>
    request(app).post('/alerts').set('authorization', auth).send({ deviceId, ...body });

  beforeAll(async () => {
    db = createPrisma(url);
    app = createApp({ db, sender: { send: async () => ({ gatewayId: null }) } });
    await db.health_centers.create({ data: { id: hc, name: 'Alerts test centre', district: 'Test', sector: 'Test' } });
    for (const [id, phone, device, centre] of [
      [chw, `+2507${tag}81`, deviceId, hc],
      [other, `+2507${tag}82`, otherDevice, hc],
      [loner, `+2507${tag}83`, lonerDevice, null],
    ] as const) {
      await db.users.create({
        data: { id, role: 'chw', full_name: 'Alerts Test CHW', phone, secret_hash: 'x', health_center_id: centre },
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
    const users = [chw, other, loner];
    await db.alert_events.deleteMany({ where: { alert: { health_center_id: hc } } });
    await db.alerts.deleteMany({ where: { health_center_id: hc } });
    await db.visits.deleteMany({ where: { chw_id: { in: users } } });
    await db.audit_log.deleteMany({ where: { actor_id: { in: users } } });
    await db.patients.deleteMany({ where: { chw_id: { in: users } } });
    await db.devices.deleteMany({ where: { user_id: { in: users } } });
    await db.users.deleteMany({ where: { id: { in: users } } });
    await db.health_centers.delete({ where: { id: hc } });
    await db.$disconnect();
  });

  it('stores the visit and one internet alert, and a retry returns the same alert', async () => {
    const p = patient();
    const v = visit(p.id);

    const first = await post({ patient: p, visit: v }).expect(200);
    expect(first.body.alert).toMatchObject({ visit_id: v.id, channel: 'internet', status: 'new' });
    const again = await post({ patient: p, visit: v }).expect(200);
    expect(again.body.alert.id).toBe(first.body.alert.id);

    expect(await db.alerts.count({ where: { visit_id: v.id } })).toBe(1);
    expect(await db.visits.findUnique({ where: { id: v.id } })).toMatchObject({
      patient_id: p.id,
      chw_id: chw,
      device_id: deviceId,
      is_urgent: true,
      source: 'sync',
      is_partial: false,
    });
    expect(await db.visit_danger_signs.findMany({ where: { visit_id: v.id } })).toEqual([{ visit_id: v.id, code: 'HB' }]);
    expect(await db.alerts.findUnique({ where: { visit_id: v.id } })).toMatchObject({ health_center_id: hc });
  });

  it('the same visit arriving later by /sync/push does not raise a second alert', async () => {
    const p = patient();
    const v = visit(p.id);
    await post({ patient: p, visit: v }).expect(200);
    await request(app)
      .post('/sync/push')
      .set('authorization', token())
      .send({
        deviceId,
        changes: [
          { seq: 1, entity: 'patient', op: 'upsert', payload: p },
          { seq: 2, entity: 'visit', op: 'upsert', payload: v },
        ],
      })
      .expect(200);
    expect(await db.alerts.count({ where: { visit_id: v.id } })).toBe(1);
    expect(await db.visits.count({ where: { id: v.id } })).toBe(1);
  });

  it('works without the patient once the patient is already on the server', async () => {
    const p = patient();
    await post({ patient: p, visit: visit(p.id) }).expect(200);
    const v = visit(p.id, { type: 'child', danger_signs: [] });
    const res = await post({ visit: v }).expect(200);
    expect(res.body.alert).toMatchObject({ visit_id: v.id, channel: 'internet' });
  });

  it('merges into the case an earlier SMS created and keeps its SMS alert (FR-14)', async () => {
    const p = patient();
    const v = visit(p.id);
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
    const sms = await db.alerts.create({ data: { visit_id: partialId, health_center_id: hc, channel: 'sms' } });

    const res = await post({ patient: p, visit: v }).expect(200);
    expect(res.body.alert).toMatchObject({ id: sms.id, visit_id: v.id, channel: 'sms' });
    expect(await db.visits.findUnique({ where: { id: partialId } })).toBeNull();
    expect(await db.patients.findUnique({ where: { id: stubId } })).toBeNull();
  });

  it('refuses non-urgent visits, foreign patients and devices, other roles and anonymous calls', async () => {
    const p = patient();
    await post({ patient: p, visit: visit(p.id, { is_urgent: false }) }).expect(400, { error: 'not_urgent' });
    await post({ visit: { id: 'nope' } }).expect(400);

    const foreign = patient();
    await request(app)
      .post('/alerts')
      .set('authorization', token(other))
      .send({ deviceId: otherDevice, patient: foreign, visit: visit(foreign.id) })
      .expect(200);
    await post({ visit: visit(foreign.id) }).expect(409, { error: 'unknown_patient' });
    await post({ patient: foreign, visit: visit(foreign.id) }).expect(409, { error: 'not_your_patient' });

    await post({ deviceId: otherDevice, patient: p, visit: visit(p.id) }).expect(403, { error: 'unknown_device' });
    await post({ patient: p, visit: visit(p.id) }, token(chw, 'supervisor')).expect(403);
    await request(app).post('/alerts').send({ deviceId, patient: p, visit: visit(p.id) }).expect(401);
  });

  it('refuses a CHW who has no health centre to alert', async () => {
    const p = patient();
    await request(app)
      .post('/alerts')
      .set('authorization', token(loner))
      .send({ deviceId: lonerDevice, patient: p, visit: visit(p.id) })
      .expect(409, { error: 'no_health_center' });
  });
});

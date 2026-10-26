import { randomInt, randomUUID } from 'node:crypto';
import type express from 'express';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { signAccess, type Role } from '../src/auth/tokens';
import { createPrisma, type Db } from '../src/db';
import { STUB_PATIENT_NAME } from '../src/sms/webhook';

// Runs against a real Postgres (CI service, or the dev DB from .env). Two health centres, each with a
// supervisor and a CHW; every row hangs off them and is deleted afterwards.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('supervisor dashboard API against Postgres', () => {
  let db: Db;
  let app: express.Express;
  const tag = randomInt(1_000_000).toString().padStart(6, '0');
  const centreA = randomUUID();
  const centreB = randomUUID();
  const supA = randomUUID();
  const supB = randomUUID();
  const chwA = randomUUID();
  const chwB = randomUUID();
  const deviceA = `SA${tag}`;
  const spareA = `SC${tag}`;
  const deviceB = `SB${tag}`;
  const users = [supA, supB, chwA, chwB];
  const t0 = new Date('2026-10-06T08:00:00Z');

  const token = (sub: string, role: Role, hc: string | null) => `Bearer ${signAccess({ sub, role, hc })}`;
  const asA = token(supA, 'supervisor', centreA);
  const asB = token(supB, 'supervisor', centreB);
  const get = (path: string, auth = asA) => request(app).get(path).set('authorization', auth);
  const patch = (id: string, body: object, auth = asA) =>
    request(app).patch(`/alerts/${id}`).set('authorization', auth).send(body);

  /** A patient, an urgent visit and its alert, created `minutes` after t0. */
  async function urgentCase(
    chw: string,
    device: string,
    centre: string,
    minutes: number,
    over: { channel?: string; partial?: boolean; stub?: boolean } = {},
  ) {
    const patientId = randomUUID();
    const visitId = randomUUID();
    const at = new Date(t0.getTime() + minutes * 60_000);
    await db.patients.create({
      data: {
        id: patientId,
        short_id: `P${patientId.slice(0, 7).toUpperCase()}`,
        chw_id: chw,
        full_name: over.stub ? STUB_PATIENT_NAME : 'Uwase Marie',
        village: over.stub ? '' : 'Nyamata',
        consent_at: at,
        created_at: at,
        updated_at: at,
      },
    });
    await db.visits.create({
      data: {
        id: visitId,
        short_code: visitId.slice(0, 8),
        patient_id: patientId,
        chw_id: chw,
        device_id: device,
        type: 'maternal',
        answers: over.partial ? { signs: ['HB'], vitals: ['T389'] } : { symptoms: 'Headache', general_condition: 'Needs attention' },
        is_urgent: true,
        recorded_at: at,
        source: over.partial ? 'sms' : 'sync',
        is_partial: over.partial ?? false,
        visit_danger_signs: { create: [{ code: 'HB' }] },
      },
    });
    return db.alerts.create({
      data: { visit_id: visitId, health_center_id: centre, channel: over.channel ?? 'internet', created_at: at },
    });
  }

  beforeAll(async () => {
    db = createPrisma(url);
    app = createApp({ db, sender: { send: async () => ({ gatewayId: null }) } });
    for (const [id, name] of [
      [centreA, 'Centre A'],
      [centreB, 'Centre B'],
    ]) {
      await db.health_centers.create({ data: { id, name, district: 'Test', sector: 'Test' } });
    }
    const people = [
      [supA, 'supervisor', centreA, 'Supervisor A', null],
      [supB, 'supervisor', centreB, 'Supervisor B', null],
      [chwA, 'chw', centreA, 'Claudine M.', 'Village A'],
      [chwB, 'chw', centreB, 'Jean Bosco', 'Village B'],
    ] as const;
    for (const [i, [id, role, hc, full_name, village]] of people.entries()) {
      await db.users.create({
        data: { id, role, full_name, village, phone: `+2507${tag}${i}0`, secret_hash: 'x', health_center_id: hc },
      });
    }
    await db.devices.createMany({
      data: [
        { id: deviceA, user_id: chwA, sms_key: new Uint8Array(60), last_sync_at: new Date('2026-10-06T09:00:00Z') },
        { id: spareA, user_id: chwA, sms_key: new Uint8Array(60), last_sync_at: new Date('2026-10-06T10:00:00Z') },
        { id: deviceB, user_id: chwB, sms_key: new Uint8Array(60) },
      ],
    });
    await db.danger_signs.upsert({
      where: { code: 'HB' },
      update: {},
      create: { code: 'HB', visit_type: 'maternal', label_en: 'Heavy bleeding', label_rw: '' },
    });
  });

  afterAll(async () => {
    if (!db) return;
    const centres = [centreA, centreB];
    await db.alert_events.deleteMany({ where: { alert: { health_center_id: { in: centres } } } });
    await db.alerts.deleteMany({ where: { health_center_id: { in: centres } } });
    await db.audit_log.deleteMany({ where: { actor_id: { in: users } } });
    await db.visits.deleteMany({ where: { chw_id: { in: users } } }); // cascades visit_danger_signs
    await db.patients.deleteMany({ where: { chw_id: { in: users } } });
    await db.devices.deleteMany({ where: { user_id: { in: users } } });
    await db.users.deleteMany({ where: { id: { in: users } } });
    await db.health_centers.deleteMany({ where: { id: { in: centres } } });
    await db.$disconnect();
  });

  it('lists the centre\'s alerts newest first, with channel, patient, CHW, village and partial flag', async () => {
    const older = await urgentCase(chwA, deviceA, centreA, 1);
    const newer = await urgentCase(chwA, deviceA, centreA, 2, { channel: 'sms', partial: true, stub: true });

    const res = await get('/alerts?status=new').expect(200);
    const ids = res.body.alerts.map((a: { id: string }) => a.id);
    expect(ids.indexOf(newer.id)).toBeLessThan(ids.indexOf(older.id));

    const sms = res.body.alerts.find((a: { id: string }) => a.id === newer.id);
    expect(sms).toMatchObject({
      status: 'new',
      channel: 'sms',
      isPartial: true,
      patient: { name: null },
      chw: { id: chwA, name: 'Claudine M.' },
      village: 'Village A', // stub patients have no village yet; the CHW's stands in
      dangerSigns: ['Heavy bleeding'],
    });
    expect(sms.patient.shortId).toMatch(/^P/);
    expect(res.body.alerts.find((a: { id: string }) => a.id === older.id)).toMatchObject({
      channel: 'internet',
      isPartial: false,
      patient: { name: 'Uwase Marie' },
      village: 'Nyamata',
    });
    expect(res.body.counts.new).toBeGreaterThanOrEqual(2);
  });

  it('filters by status, with open meaning everything not resolved', async () => {
    const done = await urgentCase(chwA, deviceA, centreA, 3);
    await db.alerts.update({ where: { id: done.id }, data: { status: 'resolved' } });

    const resolved = await get('/alerts?status=resolved').expect(200);
    expect(resolved.body.alerts.map((a: { id: string }) => a.id)).toContain(done.id);
    expect(resolved.body.alerts.every((a: { status: string }) => a.status === 'resolved')).toBe(true);

    const open = await get('/alerts?status=open').expect(200);
    expect(open.body.alerts.map((a: { id: string }) => a.id)).not.toContain(done.id);
    expect(open.body.counts.resolved).toBeGreaterThanOrEqual(1);

    await get('/alerts?status=closed').expect(400);
  });

  it('supervisor A cannot read or change centre B\'s alerts', async () => {
    const theirs = await urgentCase(chwB, deviceB, centreB, 4);

    const list = await get('/alerts').expect(200);
    expect(list.body.alerts.map((a: { id: string }) => a.id)).not.toContain(theirs.id);
    expect(await get(`/alerts/${theirs.id}`).expect(404)).toMatchObject({ body: { error: 'not_found' } });
    await patch(theirs.id, { status: 'resolved' }).expect(404);

    expect(await db.alerts.findUnique({ where: { id: theirs.id } })).toMatchObject({ status: 'new' });
    expect(await db.alert_events.count({ where: { alert_id: theirs.id } })).toBe(0);
    // Supervisor B, whose case it is, can.
    await get(`/alerts/${theirs.id}`, asB).expect(200);
  });

  it('a status change writes the event and the audit entry, and shows in the case history', async () => {
    const a = await urgentCase(chwA, deviceA, centreA, 5);

    const res = await patch(a.id, { status: 'follow_up', note: 'Follow up by 2026-10-08' }).expect(200);
    expect(res.body).toMatchObject({ id: a.id, status: 'follow_up', next: ['escalated', 'resolved'] });

    expect(await db.alerts.findUnique({ where: { id: a.id } })).toMatchObject({ status: 'follow_up' });
    expect(await db.alert_events.findMany({ where: { alert_id: a.id } })).toEqual([
      expect.objectContaining({ actor_id: supA, from_status: 'new', to_status: 'follow_up', note: 'Follow up by 2026-10-08' }),
    ]);
    expect(await db.audit_log.findMany({ where: { entity_id: a.id } })).toEqual([
      expect.objectContaining({ actor_id: supA, action: 'alert.follow_up', entity: 'alerts' }),
    ]);

    const detail = await get(`/alerts/${a.id}`).expect(200);
    expect(detail.body).toMatchObject({
      status: 'follow_up',
      next: ['escalated', 'resolved'],
      visit: { type: 'maternal', isPartial: false, answers: { symptoms: 'Headache' } },
      patient: { name: 'Uwase Marie', village: 'Nyamata' },
      chw: { id: chwA, name: 'Claudine M.' },
      dangerSigns: [{ code: 'HB', label: 'Heavy bleeding' }],
      events: [{ fromStatus: 'new', toStatus: 'follow_up', actor: 'Supervisor A', note: 'Follow up by 2026-10-08' }],
    });
    expect(detail.body.patient).not.toHaveProperty('phone');
  });

  it('refuses moves the workflow does not allow', async () => {
    const a = await urgentCase(chwA, deviceA, centreA, 6);
    await patch(a.id, { status: 'new' }).expect(400);
    await patch(a.id, { status: 'archived' }).expect(400);
    await patch(a.id, { status: 'resolved' }).expect(200);
    expect((await patch(a.id, { status: 'reviewed' }).expect(409)).body).toEqual({ error: 'invalid_transition' });
    await patch('not-a-uuid', { status: 'reviewed' }).expect(400);
    await patch(randomUUID(), { status: 'reviewed' }).expect(404);
  });

  it('two supervisors acting at once: one wins, one gets 409, one event is written', async () => {
    const a = await urgentCase(chwA, deviceA, centreA, 7);
    const results = await Promise.all([patch(a.id, { status: 'reviewed' }), patch(a.id, { status: 'reviewed' })]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(await db.alert_events.count({ where: { alert_id: a.id } })).toBe(1);
  });

  it('lists the centre\'s CHWs with their latest device sync and SMS cases still pending', async () => {
    const res = await get('/chws').expect(200);
    const ids = res.body.chws.map((c: { id: string }) => c.id);
    expect(ids).toContain(chwA);
    expect(ids).not.toContain(chwB);
    expect(ids).not.toContain(supA);

    const mine = res.body.chws.find((c: { id: string }) => c.id === chwA);
    expect(mine).toMatchObject({ name: 'Claudine M.', village: 'Village A', lastSyncAt: '2026-10-06T10:00:00.000Z' });
    expect(mine.pendingCount).toBe(await db.visits.count({ where: { chw_id: chwA, is_partial: true } }));
    expect(mine.pendingCount).toBeGreaterThanOrEqual(1);

    const theirs = await get('/chws', asB).expect(200);
    expect(theirs.body.chws).toEqual([expect.objectContaining({ id: chwB, lastSyncAt: null, pendingCount: 0 })]);
  });

  it('is for supervisors with a health centre only', async () => {
    await request(app).get('/alerts').expect(401);
    await get('/alerts', token(chwA, 'chw', centreA)).expect(403);
    await get('/chws', token(chwA, 'chw', centreA)).expect(403);
    await get('/alerts', token(supA, 'supervisor', null)).expect(403);
  });
});

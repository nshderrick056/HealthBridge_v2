import { randomUUID } from 'node:crypto';
import { Timestamp } from 'firebase-admin/firestore';
import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { bearer, centre, chw, clearEmulators, fb, idToken, makeApp, supervisor } from './emulator';

const { app, sender } = makeApp();
const { fs } = fb;
let supA: string;
let supB: string;

beforeAll(async () => {
  await clearEmulators();
  await centre('hc-a');
  await centre('hc-b');
  await chw('chw-a', 'hc-a', '+250780000501');
  await supervisor('sup-a', 'hc-a', '+250780000502');
  await supervisor('sup-b', 'hc-b', '+250780000503');
  await fs.collection('dangerSigns').doc('HB').set({ visitType: 'maternal', labelEn: 'Heavy bleeding', labelRw: '' });
  supA = bearer(await idToken('sup-a'));
  supB = bearer(await idToken('sup-b'));
});

/** An urgent visit from chw-a with its alert; [minutes] orders them in time. */
async function urgentCase(minutes: number, channel = 'internet') {
  const visitId = randomUUID();
  const patientId = randomUUID();
  await fs.collection('patients').doc(patientId).set({
    shortId: `P${minutes}`,
    chwId: 'chw-a',
    healthCenterId: 'hc-a',
    fullName: 'Uwase Marie',
    village: 'Nyamata',
  });
  await fs.collection('visits').doc(visitId).set({
    shortCode: visitId.slice(0, 8),
    patientId,
    chwId: 'chw-a',
    healthCenterId: 'hc-a',
    deviceId: 'D000001',
    type: 'maternal',
    dangerSigns: ['HB'],
    isUrgent: true,
    isPartial: false,
    recordedAt: Timestamp.fromMillis(Date.UTC(2026, 9, 6, 19, minutes)),
  });
  await fs.collection('alerts').doc(visitId).set({
    visitId,
    chwId: 'chw-a',
    healthCenterId: 'hc-a',
    channel,
    status: 'new',
    createdAt: Timestamp.fromMillis(Date.UTC(2026, 9, 6, 19, minutes)),
    ackedToChwAt: null,
  });
  return visitId;
}

describe('supervisor API', () => {
  it("lists the centre's alerts newest first with patient, CHW and signs; other centres see none", async () => {
    const older = await urgentCase(1);
    const newer = await urgentCase(2, 'sms');
    const res = await request(app).get('/alerts').set('authorization', supA).expect(200);
    const ids = res.body.alerts.map((a: { id: string }) => a.id);
    expect(ids.indexOf(newer)).toBeLessThan(ids.indexOf(older));
    expect(res.body.alerts.find((a: { id: string }) => a.id === newer)).toMatchObject({
      channel: 'sms',
      patient: { name: 'Uwase Marie' },
      chw: { id: 'chw-a', name: 'CHW chw-a' },
      village: 'Nyamata',
      dangerSigns: ['Heavy bleeding'],
    });
    expect(res.body.counts.new).toBeGreaterThanOrEqual(2);
    expect((await request(app).get('/alerts').set('authorization', supB).expect(200)).body.alerts).toEqual([]);
    await request(app).get(`/alerts/${older}`).set('authorization', supB).expect(404);
  });

  it('moves a case through allowed statuses, records who did it, and texts the CHW on escalate', async () => {
    const id = await urgentCase(3);
    const res = await request(app)
      .patch(`/alerts/${id}`)
      .set('authorization', supA)
      .send({ status: 'escalated', note: 'Refer now' })
      .expect(200);
    expect(res.body).toMatchObject({ status: 'escalated', next: ['follow_up', 'resolved'] });
    expect(sender.sent.at(-1)).toEqual({
      to: '+250780000501',
      text: `HealthBridge: case ${id.slice(0, 8)} has been escalated by the health centre.`,
    });

    const detail = await request(app).get(`/alerts/${id}`).set('authorization', supA).expect(200);
    expect(detail.body.events).toEqual([
      expect.objectContaining({ fromStatus: 'new', toStatus: 'escalated', note: 'Refer now', actor: 'Supervisor sup-a' }),
    ]);
    // Escalated cannot go back to reviewed, and a resolved case stays closed.
    await request(app).patch(`/alerts/${id}`).set('authorization', supA).send({ status: 'reviewed' }).expect(409);
    await request(app).patch(`/alerts/${id}`).set('authorization', supA).send({ status: 'resolved' }).expect(200);
    await request(app).patch(`/alerts/${id}`).set('authorization', supA).send({ status: 'follow_up' }).expect(409);
  });

  it('is for supervisors only', async () => {
    await request(app).get('/alerts').expect(401);
    await request(app).get('/alerts').set('authorization', bearer(await idToken('chw-a'))).expect(403);
  });

  it("lists the centre's CHWs with their SMS-only cases waiting for the full record", async () => {
    await fs.collection('visits').doc(randomUUID()).set({ chwId: 'chw-a', isPartial: true });
    const res = await request(app).get('/chws').set('authorization', supA).expect(200);
    expect(res.body.chws).toEqual([expect.objectContaining({ id: 'chw-a', name: 'CHW chw-a', pendingCount: 1 })]);
  });
});

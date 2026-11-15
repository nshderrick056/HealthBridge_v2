import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { MAX_CODE_ATTEMPTS, MAX_FAILED_LOGINS } from '../src/auth/routes';
import { admin, bearer, centre, chw, claimsOf, clearEmulators, exchange, fb, idToken, makeApp, supervisor } from './emulator';

const { app, sender } = makeApp();
const PHONE = '+250780000201';

beforeAll(async () => {
  await clearEmulators();
  await centre('hc-a');
  await chw('chw-a', 'hc-a', PHONE, '1357');
  await chw('chw-lock', 'hc-a', '+250780000202', '2468');
  await supervisor('sup-a', 'hc-a', '+250780000203');
  await admin();
});

const pinLogin = (phone: string, pin: string) => request(app).post('/auth/pin').send({ phone, pin });

describe('POST /auth/pin', () => {
  it('turns phone + PIN into a Firebase custom token carrying role and health centre', async () => {
    const res = await pinLogin(PHONE, '1357').expect(200);
    const token = await exchange(res.body.customToken);
    expect(claimsOf(token)).toMatchObject({ user_id: 'chw-a', role: 'chw', hc: 'hc-a' });
  });

  it('refuses a wrong PIN, an unknown phone and a malformed request alike', async () => {
    expect((await pinLogin(PHONE, '9999').expect(401)).body).toEqual({ error: 'invalid_credentials' });
    expect((await pinLogin('+250780000299', '1357').expect(401)).body).toEqual({ error: 'invalid_credentials' });
    await pinLogin(PHONE, '12').expect(400);
  });

  it(`locks the PIN for 15 minutes after ${MAX_FAILED_LOGINS} wrong tries`, async () => {
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) await pinLogin('+250780000202', '0000').expect(401);
    expect((await pinLogin('+250780000202', '2468').expect(429)).body).toEqual({ error: 'too_many_attempts' });
  });
});

describe('forgot PIN / password, approved by an admin', () => {
  it('request -> admin approves -> texted code -> new PIN; the old PIN stops working', async () => {
    await request(app).post('/auth/reset/request').send({ phone: PHONE }).expect(200);
    // Asking twice does not pile up requests.
    await request(app).post('/auth/reset/request').send({ phone: PHONE }).expect(200);

    const adminToken = bearer(await idToken('admin-1'));
    const list = await request(app).get('/admin/reset-requests').set('authorization', adminToken).expect(200);
    const mine = list.body.requests.filter((r: { userId: string }) => r.userId === 'chw-a');
    expect(mine).toHaveLength(1);
    expect(mine[0]).toMatchObject({ name: 'CHW chw-a', phone: PHONE, role: 'chw' });

    await request(app).post(`/admin/reset-requests/${mine[0].id}/approve`).set('authorization', adminToken).expect(200);
    const text = sender.sent.at(-1)!;
    expect(text.to).toBe(PHONE);
    const code = /code is (\d{6})/.exec(text.text)![1];

    const wrong = code === '000000' ? '111111' : '000000';
    await request(app).post('/auth/reset/verify').send({ phone: PHONE, code: wrong }).expect(401);
    const ok = await request(app).post('/auth/reset/verify').send({ phone: PHONE, code }).expect(200);
    await request(app).post('/auth/reset/complete').send({ resetToken: ok.body.resetToken, pin: '8642' }).expect(200);
    // The reset token is single-use.
    await request(app).post('/auth/reset/complete').send({ resetToken: ok.body.resetToken, pin: '1111' }).expect(401);

    await pinLogin(PHONE, '1357').expect(401);
    await pinLogin(PHONE, '8642').expect(200);
    const audit = await fb.fs.collection('auditLog').where('entityId', '==', mine[0].id).get();
    expect(audit.docs.map((d) => d.data().action).sort()).toEqual(['reset.approve', 'reset.complete', 'reset.request']);
  });

  it(`closes an approved request after ${MAX_CODE_ATTEMPTS} wrong codes`, async () => {
    await request(app).post('/auth/reset/request').send({ phone: '+250780000203' }).expect(200);
    const adminToken = bearer(await idToken('admin-1'));
    const { body } = await request(app).get('/admin/reset-requests').set('authorization', adminToken);
    const id = body.requests.find((r: { userId: string }) => r.userId === 'sup-a').id;
    await request(app).post(`/admin/reset-requests/${id}/approve`).set('authorization', adminToken).expect(200);
    const code = /code is (\d{6})/.exec(sender.sent.at(-1)!.text)![1];
    const wrong = code === '000000' ? '111111' : '000000';
    for (let i = 0; i < MAX_CODE_ATTEMPTS; i++) {
      await request(app).post('/auth/reset/verify').send({ email: 'sup-a@example.test', code: wrong }).expect(401);
    }
    await request(app).post('/auth/reset/verify').send({ email: 'sup-a@example.test', code }).expect(401);
    expect((await fb.fs.collection('resetRequests').doc(id).get()).data()?.status).toBe('expired');
  });

  it('answers the same for unknown accounts and records nothing', async () => {
    const before = (await fb.fs.collection('resetRequests').get()).size;
    await request(app).post('/auth/reset/request').send({ phone: '+250780000999' }).expect(200);
    await request(app).post('/auth/reset/request').send({ email: 'nobody@example.test' }).expect(200);
    expect((await fb.fs.collection('resetRequests').get()).size).toBe(before);
  });

  it('only admins see and approve requests, and an SMS failure keeps the request pending', async () => {
    const chwToken = bearer(await idToken('chw-a'));
    await request(app).get('/admin/reset-requests').set('authorization', chwToken).expect(403);
    await request(app).get('/admin/reset-requests').expect(401);

    await request(app).post('/auth/reset/request').send({ phone: '+250780000202' }).expect(200);
    const adminToken = bearer(await idToken('admin-1'));
    const { body } = await request(app).get('/admin/reset-requests').set('authorization', adminToken);
    const id = body.requests.find((r: { userId: string }) => r.userId === 'chw-lock').id;
    sender.fail = true;
    await request(app).post(`/admin/reset-requests/${id}/approve`).set('authorization', adminToken).expect(502);
    sender.fail = false;
    expect((await fb.fs.collection('resetRequests').doc(id).get()).data()?.status).toBe('pending');
  });
});

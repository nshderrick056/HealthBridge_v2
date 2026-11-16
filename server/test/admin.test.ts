import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { admin, bearer, centre, chw, claimsOf, clearEmulators, exchange, fb, idToken, makeApp } from './emulator';

const { app, sender } = makeApp();
let adminToken: string;

beforeAll(async () => {
  await clearEmulators();
  await admin();
  await centre('hc-a');
  await chw('chw-x', 'hc-a', '+250780000301');
  adminToken = bearer(await idToken('admin-1'));
});

const post = (path: string, body: object, auth = adminToken) => request(app).post(path).set('authorization', auth).send(body);

describe('admin accounts (no self sign-up)', () => {
  it('is for admins only', async () => {
    await request(app).post('/admin/users').send({}).expect(401);
    await post('/admin/users', {}, bearer(await idToken('chw-x'))).expect(403);
  });

  it('creates a CHW, texts a temporary PIN, and makes them choose their own at first sign-in', async () => {
    const hc = (await post('/admin/health-centers', { name: 'Gatare HC', district: 'Nyamagabe', sector: 'Gatare' }).expect(201)).body.id;
    const res = await post('/admin/users', {
      role: 'chw',
      fullName: 'Mukamana Alice',
      phone: '+250780000310',
      chwRole: 'binome',
      village: 'Gatare',
      healthCenterId: hc,
    }).expect(201);
    expect(res.body.smsSent).toBe(true);

    const user = (await fb.fs.collection('users').doc(res.body.id).get()).data();
    expect(user).toMatchObject({ role: 'chw', fullName: 'Mukamana Alice', healthCenterId: hc, active: true });
    const sms = sender.sent.at(-1)!;
    expect(sms.to).toBe('+250780000310');
    const temp = /PIN (\d{6})/.exec(sms.text)![1];
    // The admin never sees it, and the hash stays in the server-only collection.
    expect(JSON.stringify(res.body)).not.toContain(temp);
    expect((await fb.fs.collection('credentials').doc(res.body.id).get()).data()?.pinHash).toMatch(/^\$argon2id\$/);

    const first = await request(app).post('/auth/pin').send({ phone: '+250780000310', pin: temp }).expect(200);
    const token = await exchange(first.body.customToken);
    expect(claimsOf(token)).toMatchObject({ role: 'chw', hc, mc: true });

    const change = (body: object) => request(app).post('/auth/change').set('authorization', bearer(token)).send(body);
    await change({}).expect(400); // the PIN must be replaced
    await change({ pin: '2468' }).expect(200);
    await change({ pin: '1111' }).expect(403); // only once, while it is still temporary

    await request(app).post('/auth/pin').send({ phone: '+250780000310', pin: temp }).expect(401);
    const own = await request(app).post('/auth/pin').send({ phone: '+250780000310', pin: '2468' }).expect(200);
    expect(claimsOf(await exchange(own.body.customToken)).mc).toBeUndefined();
  });

  it('still creates the account when the SMS fails, and says so', async () => {
    sender.fail = true;
    try {
      const res = await post('/admin/users', {
        role: 'chw', fullName: 'Uwase Diane', phone: '+250780000312', chwRole: 'asm', village: 'Kigeme', healthCenterId: 'hc-a',
      }).expect(201);
      expect(res.body.smsSent).toBe(false);
    } finally {
      sender.fail = false;
    }
  });

  it('lists health centres by name for the account form', async () => {
    const res = await request(app).get('/admin/health-centers').set('authorization', adminToken).expect(200);
    const names = res.body.centres.map((c: { name: string }) => c.name);
    expect(names).toEqual([...names].sort((a: string, b: string) => a.localeCompare(b)));
    expect(res.body.centres).toEqual(expect.arrayContaining([expect.objectContaining({ id: 'hc-a', name: 'Centre hc-a' })]));
  });

  it('creates a supervisor with a temporary password, replaced at first sign-in', async () => {
    const res = await post('/admin/users', {
      role: 'supervisor',
      fullName: 'Nyirahabimana Grace',
      phone: '+250780000311',
      email: 'grace@example.test',
      healthCenterId: 'hc-a',
    }).expect(201);
    const account = await fb.auth.getUser(res.body.id);
    expect(account.email).toBe('grace@example.test');
    expect(account.customClaims).toEqual({ role: 'supervisor', hc: 'hc-a', mc: true });
    expect(sender.sent.at(-1)!.text).toMatch(/email grace@example\.test and password \S{12}\./);

    const token = await idToken(res.body.id);
    await request(app).post('/auth/change').set('authorization', bearer(token)).send({ pin: '1234' }).expect(400);
    await request(app).post('/auth/change').set('authorization', bearer(token)).send({ password: 'my-own-password' }).expect(200);
    expect((await fb.auth.getUser(res.body.id)).customClaims).toEqual({ role: 'supervisor', hc: 'hc-a' });
  });

  it('refuses duplicates, admins and unknown health centres', async () => {
    const base = { role: 'chw', fullName: 'Habimana Noel', chwRole: 'asm', village: 'Rugarama', healthCenterId: 'hc-a' };
    await post('/admin/users', { ...base, phone: '+250780000320' }).expect(201);
    expect((await post('/admin/users', { ...base, phone: '+250780000320' }).expect(409)).body).toEqual({ error: 'phone_or_email_taken' });
    await post('/admin/users', { ...base, phone: '+250780000322', role: 'admin' }).expect(400);
    await post('/admin/users', { ...base, phone: '0780000323' }).expect(400); // not international format
    expect((await post('/admin/users', { ...base, phone: '+250780000324', healthCenterId: 'nope' }).expect(400)).body).toEqual({
      error: 'unknown_health_center',
    });
  });
});

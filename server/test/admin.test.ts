import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { admin, bearer, centre, chw, claimsOf, clearEmulators, exchange, fb, idToken, makeApp } from './emulator';

const { app } = makeApp();
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

  it('creates a health centre, then a CHW who can sign in with phone + PIN', async () => {
    const hc = (await post('/admin/health-centers', { name: 'Gatare HC', district: 'Nyamagabe', sector: 'Gatare' }).expect(201)).body.id;
    const res = await post('/admin/users', {
      role: 'chw',
      fullName: 'Mukamana Alice',
      phone: '+250780000310',
      pin: '482913',
      chwRole: 'binome',
      village: 'Gatare',
      healthCenterId: hc,
    }).expect(201);

    const user = (await fb.fs.collection('users').doc(res.body.id).get()).data();
    expect(user).toMatchObject({ role: 'chw', fullName: 'Mukamana Alice', healthCenterId: hc, active: true });
    // The PIN hash is in the server-only collection, never on the profile.
    expect(JSON.stringify(user)).not.toContain('482913');
    expect((await fb.fs.collection('credentials').doc(res.body.id).get()).data()?.pinHash).toMatch(/^\$argon2id\$/);

    const login = await request(app).post('/auth/pin').send({ phone: '+250780000310', pin: '482913' }).expect(200);
    expect(claimsOf(await exchange(login.body.customToken))).toMatchObject({ role: 'chw', hc });
  });

  it('creates a supervisor with an email + password Firebase account and role claims', async () => {
    const res = await post('/admin/users', {
      role: 'supervisor',
      fullName: 'Nyirahabimana Grace',
      phone: '+250780000311',
      email: 'grace@example.test',
      password: 'long-enough-password',
      healthCenterId: 'hc-a',
    }).expect(201);
    const account = await fb.auth.getUser(res.body.id);
    expect(account.email).toBe('grace@example.test');
    expect(account.customClaims).toEqual({ role: 'supervisor', hc: 'hc-a' });
  });

  it('refuses duplicates, weak PINs, admins and unknown health centres', async () => {
    const base = { role: 'chw', fullName: 'Habimana Noel', pin: '1357', chwRole: 'asm', village: 'Rugarama', healthCenterId: 'hc-a' };
    await post('/admin/users', { ...base, phone: '+250780000320' }).expect(201);
    expect((await post('/admin/users', { ...base, phone: '+250780000320' }).expect(409)).body).toEqual({ error: 'phone_or_email_taken' });
    await post('/admin/users', { ...base, phone: '+250780000321', pin: '12' }).expect(400);
    await post('/admin/users', { ...base, phone: '+250780000322', role: 'admin' }).expect(400);
    await post('/admin/users', { ...base, phone: '0780000323' }).expect(400); // not international format
    expect((await post('/admin/users', { ...base, phone: '+250780000324', healthCenterId: 'nope' }).expect(400)).body).toEqual({
      error: 'unknown_health_center',
    });
  });
});

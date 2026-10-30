import { randomInt, randomUUID } from 'node:crypto';
import type express from 'express';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { signAccess, type Role } from '../src/auth/tokens';
import { createPrisma, type Db } from '../src/db';

// Runs against a real Postgres (CI service, or the dev DB from .env); everything it creates is deleted.
const url = process.env.DATABASE_URL;

describe.skipIf(!url)('admin account management against Postgres', () => {
  let db: Db;
  let app: express.Express;
  const tag = randomInt(1_000_000).toString().padStart(6, '0');
  const admin = randomUUID();
  const centres: string[] = [];
  const phoneFor = (n: number) => `+2507${tag}${n}`;

  const auth = (role: Role = 'admin', sub = admin) => `Bearer ${signAccess({ sub, role, hc: null })}`;
  const post = (path: string, body: object, as = auth()) => request(app).post(path).set('authorization', as).send(body);

  async function centre() {
    const res = await post('/admin/health-centers', { name: `Admin test centre ${tag}`, district: 'Test', sector: 'Test' }).expect(201);
    centres.push(res.body.id);
    return res.body.id as string;
  }

  beforeAll(async () => {
    db = createPrisma(url);
    app = createApp({ db, sender: { send: async () => ({ gatewayId: null }) } });
    await db.users.create({
      data: { id: admin, role: 'admin', full_name: 'Test Admin', phone: phoneFor(90), secret_hash: 'x' },
    });
  });

  afterAll(async () => {
    if (!db) return;
    const made = await db.users.findMany({ where: { phone: { startsWith: `+2507${tag}` } }, select: { id: true } });
    const ids = made.map((u) => u.id);
    await db.audit_log.deleteMany({ where: { actor_id: { in: ids } } });
    await db.users.deleteMany({ where: { id: { in: ids } } });
    await db.health_centers.deleteMany({ where: { id: { in: centres } } });
    await db.$disconnect();
  });

  it('is for admins only', async () => {
    await request(app).post('/admin/users').send({}).expect(401);
    await post('/admin/users', {}, auth('supervisor')).expect(403);
    await post('/admin/health-centers', {}, auth('chw')).expect(403);
  });

  it('creates a CHW who can then log in on the phone with phone + PIN', async () => {
    const hc = await centre();
    const res = await post('/admin/users', {
      role: 'chw',
      fullName: 'Mukamana Alice',
      phone: phoneFor(1),
      pin: '482913',
      chwRole: 'binome',
      village: 'Gatare',
      healthCenterId: hc,
    }).expect(201);
    expect(res.body).toMatchObject({ role: 'chw', fullName: 'Mukamana Alice' });

    const login = await request(app).post('/auth/login').send({ phone: phoneFor(1), pin: '482913' }).expect(200);
    expect(login.body.user).toMatchObject({ role: 'chw', healthCenterId: hc });
    expect(await db.audit_log.findFirst({ where: { actor_id: admin, entity_id: res.body.id } })).toMatchObject({
      action: 'user.create',
    });
  });

  it('creates a supervisor who can log in on the dashboard with email + password', async () => {
    const hc = await centre();
    const email = `sup${tag}@example.test`;
    await post('/admin/users', {
      role: 'supervisor',
      fullName: 'Nyirahabimana Grace',
      phone: phoneFor(2),
      email,
      password: 'long-enough-password',
      healthCenterId: hc,
    }).expect(201);
    const login = await request(app).post('/auth/login').send({ email, password: 'long-enough-password' }).expect(200);
    expect(login.body.user).toMatchObject({ role: 'supervisor', healthCenterId: hc });
  });

  it('refuses duplicates, weak PINs and unknown health centres', async () => {
    const hc = await centre();
    const chw = { role: 'chw', fullName: 'Habimana Noel', phone: phoneFor(3), pin: '1357', chwRole: 'asm', village: 'Rugarama', healthCenterId: hc };
    await post('/admin/users', chw).expect(201);
    expect((await post('/admin/users', chw).expect(409)).body).toEqual({ error: 'phone_or_email_taken' });
    await post('/admin/users', { ...chw, phone: phoneFor(4), pin: '12' }).expect(400);
    await post('/admin/users', { ...chw, phone: phoneFor(5), role: 'admin' }).expect(400); // admins are not created over the API
    expect((await post('/admin/users', { ...chw, phone: phoneFor(6), healthCenterId: randomUUID() }).expect(400)).body).toEqual({
      error: 'unknown_health_center',
    });
  });
});

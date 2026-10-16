import { hash } from '@node-rs/argon2';
import express from 'express';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { MAX_FAILED_LOGINS } from '../src/auth/routes';
import { signAccess, verifyAccess } from '../src/auth/tokens';
import type { Db } from '../src/db';
import { requireAuth, requireRole } from '../src/middleware/auth';

type User = {
  id: string;
  role: 'chw' | 'supervisor' | 'admin';
  full_name: string;
  phone: string;
  email: string | null;
  secret_hash: string;
  health_center_id: string | null;
  language: string;
  active: boolean;
  failed_logins: number;
  locked_until: Date | null;
};

// Just enough of Prisma's users delegate for the auth routes.
function fakeDb(users: User[]) {
  const matches = (u: User, where: Record<string, unknown>) =>
    Object.entries(where).every(([k, v]) => u[k as keyof User] === v);
  return {
    users: {
      findFirst: async ({ where }: { where: Record<string, unknown> }) =>
        users.find((u) => matches(u, where)) ?? null,
      update: async ({ where, data }: { where: { id: string }; data: Record<string, any> }) => {
        const u = users.find((x) => x.id === where.id)!;
        for (const [k, v] of Object.entries(data)) {
          (u as any)[k] = v && typeof v === 'object' && 'increment' in v ? (u as any)[k] + v.increment : v;
        }
        return u;
      },
    },
  } as unknown as Db;
}

let users: User[];
let app: express.Express;

beforeEach(async () => {
  users = [
    {
      id: '00000000-0000-4000-8000-000000000001',
      role: 'chw',
      full_name: 'Test CHW',
      phone: '+250780000001',
      email: null,
      secret_hash: await hash('1234'),
      health_center_id: '00000000-0000-4000-8000-0000000000aa',
      language: 'rw',
      active: true,
      failed_logins: 0,
      locked_until: null,
    },
    {
      id: '00000000-0000-4000-8000-000000000002',
      role: 'supervisor',
      full_name: 'Test Supervisor',
      phone: '+250780000002',
      email: 'sup@example.test',
      secret_hash: await hash('correct-horse-battery'),
      health_center_id: '00000000-0000-4000-8000-0000000000aa',
      language: 'en',
      active: true,
      failed_logins: 0,
      locked_until: null,
    },
  ];
  app = createApp({ db: fakeDb(users) });
});

const login = (body: object) => request(app).post('/auth/login').send(body);

describe('GET /health', () => {
  it('answers without auth', async () => {
    await request(app).get('/health').expect(200, { ok: true });
    await request(app).head('/health').expect(200);
  });
});

describe('POST /auth/login', () => {
  it('logs a CHW in with phone + PIN', async () => {
    const res = await login({ phone: '+250780000001', pin: '1234' }).expect(200);
    expect(verifyAccess(res.body.accessToken)).toMatchObject({ sub: users[0].id, role: 'chw' });
    expect(res.body.refreshToken).toBeTypeOf('string');
    expect(res.body.user).toEqual({
      id: users[0].id,
      role: 'chw',
      fullName: 'Test CHW',
      healthCenterId: users[0].health_center_id,
      language: 'rw',
    });
    expect(res.body.user).not.toHaveProperty('secret_hash');
  });

  it('logs a supervisor in with email + password', async () => {
    await login({ email: 'sup@example.test', password: 'correct-horse-battery' }).expect(200);
  });

  it('rejects a wrong PIN, an unknown phone and an inactive user the same way', async () => {
    await login({ phone: '+250780000001', pin: '9999' }).expect(401, { error: 'invalid_credentials' });
    await login({ phone: '+250789999999', pin: '1234' }).expect(401, { error: 'invalid_credentials' });
    users[0].active = false;
    await login({ phone: '+250780000001', pin: '1234' }).expect(401, { error: 'invalid_credentials' });
  });

  it('locks the account after repeated wrong PINs, then resets on success', async () => {
    for (let i = 0; i < MAX_FAILED_LOGINS; i++) {
      await login({ phone: '+250780000001', pin: '0000' }).expect(401);
    }
    await login({ phone: '+250780000001', pin: '1234' }).expect(429);

    users[0].locked_until = new Date(Date.now() - 1000); // lock expired
    await login({ phone: '+250780000001', pin: '1234' }).expect(200);
    expect(users[0]).toMatchObject({ failed_logins: 0, locked_until: null });
  });

  it('validates the body', async () => {
    await login({ phone: '+250780000001', pin: '12' }).expect(400);
    await login({}).expect(400);
    await request(app).post('/auth/login').set('content-type', 'application/json').send('{bad').expect(400);
  });
});

describe('POST /auth/refresh', () => {
  it('issues a new access token for a refresh token', async () => {
    const { body } = await login({ phone: '+250780000001', pin: '1234' });
    const res = await request(app).post('/auth/refresh').send({ refreshToken: body.refreshToken }).expect(200);
    expect(verifyAccess(res.body.accessToken).sub).toBe(users[0].id);
  });

  it('rejects an access token used as a refresh token, and deactivated users', async () => {
    const { body } = await login({ phone: '+250780000001', pin: '1234' });
    await request(app).post('/auth/refresh').send({ refreshToken: body.accessToken }).expect(401);
    users[0].active = false;
    await request(app).post('/auth/refresh').send({ refreshToken: body.refreshToken }).expect(401);
  });
});

describe('requireAuth / requireRole', () => {
  const guarded = express()
    .get('/sup', requireAuth, requireRole('supervisor'), (_req, res) => {
      res.json(res.locals.auth);
    });
  const token = (role: 'chw' | 'supervisor') => signAccess({ sub: 'u1', role, hc: 'hc1' });

  it('401 without a token, with a bad token, or with an expired token', async () => {
    await request(guarded).get('/sup').expect(401);
    await request(guarded).get('/sup').set('authorization', 'Bearer nope').expect(401);
    const expired = jwt.sign({ sub: 'u1', role: 'supervisor', hc: null }, process.env.JWT_SECRET!, {
      expiresIn: -10,
    });
    await request(guarded).get('/sup').set('authorization', `Bearer ${expired}`).expect(401);
  });

  it('403 for the wrong role, 200 for the right one', async () => {
    await request(guarded).get('/sup').set('authorization', `Bearer ${token('chw')}`).expect(403);
    const res = await request(guarded).get('/sup').set('authorization', `Bearer ${token('supervisor')}`).expect(200);
    expect(res.body).toEqual({ sub: 'u1', role: 'supervisor', hc: 'hc1' });
  });
});

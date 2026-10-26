import { randomBytes } from 'node:crypto';
import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../src/app';
import { signAccess } from '../src/auth/tokens';
import type { Db } from '../src/db';
import { encodePlaintext, seal, type AlertFields } from '../src/sms/codec';
import { unwrapKey, wrapKey } from '../src/sms/keystore';
import { parsePhoneTime } from '../src/sms/webhook';

const SECRET = 'test-webhook-secret-1234';
const HC = '00000000-0000-4000-8000-0000000000aa';
const CHW = '00000000-0000-4000-8000-000000000001';
const PHONE = '+250780000001';

type Row = Record<string, any>;
const unique = () => Object.assign(new Error('unique'), { code: 'P2002' });
const hex = (b: unknown) => Buffer.from(b as Uint8Array).toString('hex');

// In-memory stand-in for the handful of Prisma calls the SMS routes make. Enforces the same UNIQUE
// constraints as the schema, and rolls back on a failed $transaction.
function fakeDb() {
  const t = {
    users: [{ id: CHW, role: 'chw', active: true, health_center_id: HC }] as Row[],
    devices: [] as Row[],
    sms_messages: [] as Row[],
    patients: [] as Row[],
    visits: [] as Row[],
    visit_danger_signs: [] as Row[],
    alerts: [] as Row[],
    danger_signs: [{ code: 'HB' }, { code: 'CV' }] as Row[],
  };
  let seq = 0n;
  const match = (r: Row, where: Row = {}): boolean =>
    Object.entries(where).every(([k, v]) => {
      if (v && typeof v === 'object' && 'startsWith' in v) return String(r[k]).startsWith(v.startsWith);
      if (v && typeof v === 'object' && 'gte' in v) return r[k] >= v.gte;
      if (v && typeof v === 'object' && 'in' in v) return v.in.includes(r[k]);
      return r[k] === v;
    });
  const find = (rows: Row[], where?: Row) => rows.find((r) => match(r, where)) ?? null;

  const db: any = {
    users: { findFirst: async ({ where }: Row) => find(t.users, where) },
    devices: {
      create: async ({ data }: Row) => {
        if (find(t.devices, { id: data.id })) throw unique();
        t.devices.push({ revoked_at: null, ...data });
      },
      findFirst: async ({ where }: Row) => {
        const d = find(t.devices, where);
        return d && { ...d, user: find(t.users, { id: d.user_id }) };
      },
    },
    sms_messages: {
      create: async ({ data }: Row) => {
        if (data.nonce && t.sms_messages.some((m) => m.device_id === data.device_id && m.nonce && hex(m.nonce) === hex(data.nonce))) throw unique();
        t.sms_messages.push({ id: ++seq, created_at: new Date(), ...data });
      },
      findMany: async ({ where }: Row) => t.sms_messages.filter((m) => match(m, where)).reverse(),
      findFirst: async ({ where }: Row) => find(t.sms_messages, where),
      update: async ({ where, data }: Row) => Object.assign(find(t.sms_messages, where)!, data),
    },
    patients: {
      findFirst: async ({ where }: Row) => find(t.patients, where),
      create: async ({ data }: Row) => (t.patients.push(data), data),
    },
    visits: {
      findFirst: async ({ where }: Row) => find(t.visits, where),
      create: async ({ data: { visit_danger_signs, ...data } }: Row) => {
        t.visits.push(data);
        for (const s of visit_danger_signs.create) t.visit_danger_signs.push({ visit_id: data.id, ...s });
        return data;
      },
    },
    danger_signs: { findMany: async ({ where }: Row) => t.danger_signs.filter((r) => match(r, where)) },
    alerts: {
      upsert: async ({ where, create }: Row) => {
        if (!find(t.alerts, where)) t.alerts.push({ acked_to_chw_at: null, ...create });
      },
      updateMany: async ({ where, data }: Row) => t.alerts.filter((a) => match(a, where)).forEach((a) => Object.assign(a, data)),
    },
    $transaction: async (fn: (tx: unknown) => Promise<unknown>) => {
      const snapshot = Object.fromEntries(Object.entries(t).map(([k, v]) => [k, v.map((r) => ({ ...r }))]));
      try {
        return await fn(db);
      } catch (e) {
        Object.assign(t, snapshot);
        throw e;
      }
    },
  };
  return { db: db as Db, t };
}

const fields: AlertFields = {
  shortCode: '7f3c9a21',
  patient: 'P0412',
  type: 'M',
  time: '2610062114',
  signs: ['HB', 'CV'],
  vitals: ['T389', 'G32'],
};

let t: ReturnType<typeof fakeDb>['t'];
let app: ReturnType<typeof createApp>;
let sent: { to: string; text: string }[];
let key: Buffer;
let sendFails = false;

const register = (buildFlavor = 'managed') =>
  request(app)
    .post('/devices/register')
    .set('Authorization', `Bearer ${signAccess({ sub: CHW, role: 'chw', hc: HC })}`)
    .send({ buildFlavor, simPhone: PHONE });

const post = (path: string, form: Record<string, string>, secret: string | null = SECRET) =>
  request(app)
    .post(`/webhooks/sms${path}${secret ? `?secret=${secret}` : ''}`)
    .type('form')
    .send(form);

beforeEach(async () => {
  const f = fakeDb();
  t = f.t;
  sent = [];
  sendFails = false;
  app = createApp({
    db: f.db,
    sender: {
      send: async (to, text) => {
        if (sendFails) throw new Error('gateway down');
        sent.push({ to, text });
        return { gatewayId: `ATXid_${sent.length}` };
      },
    },
  });
  key = Buffer.from((await register()).body.smsKey, 'base64');
});

const deviceId = () => t.devices[0].id as string;
const sms = (f = fields, nonce = randomBytes(12)) => seal(key, deviceId(), encodePlaintext(f), nonce);

describe('POST /devices/register', () => {
  it('issues an ID and a 32-byte key once, and stores the key wrapped', async () => {
    expect(key).toHaveLength(32);
    expect(deviceId()).toMatch(/^D\d{6}$/);
    expect(t.devices[0].build_flavor).toBe('managed');
    expect(hex(t.devices[0].sms_key)).not.toContain(key.toString('hex'));
    expect(unwrapKey(t.devices[0].sms_key).equals(key)).toBe(true);
  });

  it('requires a CHW and a valid flavour', async () => {
    const sup = signAccess({ sub: CHW, role: 'supervisor', hc: HC });
    expect((await request(app).post('/devices/register').send({ buildFlavor: 'store' })).status).toBe(401);
    expect((await request(app).post('/devices/register').set('Authorization', `Bearer ${sup}`).send({ buildFlavor: 'store' })).status).toBe(403);
    expect((await register('beta')).status).toBe(400);
  });
});

describe('POST /webhooks/sms', () => {
  it('rejects a wrong or missing secret', async () => {
    const [text] = sms();
    expect((await post('', { from: PHONE, text }, 'wrong-secret-wrong!')).status).toBe(401);
    expect((await post('', { from: PHONE, text }, null)).status).toBe(401);
    expect(t.alerts).toHaveLength(0);
  });

  it('turns a valid SMS into a partial urgent visit and alert, then acknowledges', async () => {
    const [text] = sms();
    expect((await post('', { from: PHONE, text })).status).toBe(200);

    expect(t.alerts).toHaveLength(1);
    expect(t.alerts[0]).toMatchObject({ channel: 'sms', health_center_id: HC });
    expect(t.visits[0]).toMatchObject({
      short_code: '7f3c9a21', type: 'maternal', source: 'sms', is_partial: true, is_urgent: true,
      recorded_at: new Date('2026-10-06T19:14:00Z'), // 21:14 Kigali
    });
    expect(t.visit_danger_signs.map((s) => s.code)).toEqual(['HB', 'CV']);
    expect(t.patients[0]).toMatchObject({ short_id: 'P0412', chw_id: CHW });
    expect(sent).toEqual([{ to: PHONE, text: 'HB OK 7f3c9a21' }]);
  });

  it('keeps the alert when the ack cannot be sent', async () => {
    sendFails = true;
    const [text] = sms();
    expect((await post('', { from: PHONE, text })).status).toBe(200);
    expect(t.alerts).toHaveLength(1);
    expect(t.sms_messages.at(-1)).toMatchObject({ direction: 'out', status: 'failed' });
  });

  it('ignores a replayed SMS: one alert, one ack', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text });
    await post('', { from: PHONE, text });
    expect(t.alerts).toHaveLength(1);
    expect(sent).toHaveLength(1);
    expect(t.sms_messages.filter((m) => m.error === 'replay')).toHaveLength(1);
  });

  it('logs tampered, unknown-device and non-HealthBridge messages without replying', async () => {
    const [text] = sms();
    const tampered = text.slice(0, -4) + (text.endsWith('AAAA') ? 'BBBB' : 'AAAA');
    const stranger = text.replace(deviceId(), 'D999999');
    for (const bad of [tampered, stranger, 'hello there']) await post('', { from: PHONE, text: bad });
    expect(t.alerts).toHaveLength(0);
    expect(sent).toHaveLength(0);
    expect(t.sms_messages.map((m) => m.error)).toEqual(['authentication failed', 'unknown_device', 'not_healthbridge']);
  });

  it('rejects an SMS for a patient that belongs to another CHW', async () => {
    t.patients.push({ id: 'p1', short_id: 'P0412', chw_id: 'someone-else' });
    const [text] = sms();
    await post('', { from: PHONE, text });
    expect(t.alerts).toHaveLength(0);
    expect(sent).toHaveLength(0);
  });

  it('reassembles two parts arriving in reverse order into one alert', async () => {
    const long = { ...fields, signs: ['HB', 'CV', 'SH', 'UD', 'VE', 'CC'], vitals: ['T389', 'G32', 'W123', 'H456', 'R987', 'A111', 'B222', 'C333', 'D444', 'E555', 'F666'] };
    const [p1, p2] = sms(long);
    expect(p2).toBeDefined();
    await post('', { from: PHONE, text: p2 });
    expect(t.alerts).toHaveLength(0);
    expect(sent).toHaveLength(0);
    await post('', { from: PHONE, text: p1 });
    expect(t.alerts).toHaveLength(1);
    expect(sent).toHaveLength(1);
    // replaying the pair adds nothing
    await post('', { from: PHONE, text: p2 });
    await post('', { from: PHONE, text: p1 });
    expect(t.alerts).toHaveLength(1);
    expect(sent).toHaveLength(1);
  });

  it('reuses a visit that already exists from the internet path', async () => {
    t.patients.push({ id: 'p1', short_id: 'P0412', chw_id: CHW });
    t.visits.push({ id: 'v1', device_id: deviceId(), short_code: '7f3c9a21' });
    const [text] = sms();
    await post('', { from: PHONE, text });
    expect(t.visits).toHaveLength(1);
    expect(t.alerts[0].visit_id).toBe('v1');
  });
});

describe('POST /webhooks/sms/delivery', () => {
  it('marks the outbound ack delivered and stamps the alert', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text });
    expect(t.alerts[0].acked_to_chw_at).toBeNull();
    expect((await post('/delivery', { id: 'ATXid_1', status: 'Success' })).status).toBe(200);
    expect(t.sms_messages.at(-1)).toMatchObject({ status: 'delivered' });
    expect(t.alerts[0].acked_to_chw_at).toBeInstanceOf(Date);
  });

  it('records a failed delivery without stamping the alert', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text });
    await post('/delivery', { id: 'ATXid_1', status: 'Failed' });
    expect(t.sms_messages.at(-1)).toMatchObject({ status: 'failed', error: 'Failed' });
    expect(t.alerts[0].acked_to_chw_at).toBeNull();
  });

  it('needs the secret', async () => {
    expect((await post('/delivery', { id: 'x', status: 'Success' }, null)).status).toBe(401);
  });
});

describe('helpers', () => {
  it('parsePhoneTime converts Kigali time to UTC and rejects impossible dates', () => {
    expect(parsePhoneTime('2610062114')?.toISOString()).toBe('2026-10-06T19:14:00.000Z');
    expect(parsePhoneTime('2601010030')?.toISOString()).toBe('2025-12-31T22:30:00.000Z');
    expect(parsePhoneTime('2613062114')).toBeNull();
    expect(parsePhoneTime('2602302114')).toBeNull();
  });

  it('wrapKey round-trips and is randomised', () => {
    const k = randomBytes(32);
    expect(wrapKey(k).equals(wrapKey(k))).toBe(false);
    expect(unwrapKey(wrapKey(k)).equals(k)).toBe(true);
  });
});

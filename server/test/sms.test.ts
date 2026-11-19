import { randomBytes, randomUUID } from 'node:crypto';
import { Timestamp } from 'firebase-admin/firestore';
import request from 'supertest';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { ackTag, encodePlaintext, seal, type AlertFields } from '../src/sms/codec';
import { unwrapKey } from '../src/sms/keystore';
import { STUB_PATIENT_NAME } from '../src/sms/webhook';
import { bearer, centre, chw, clearEmulators, fb, idToken, makeApp } from './emulator';

const SECRET = 'test-webhook-secret-1234';
const PHONE = '+250780000401';
const { app, sender } = makeApp();
const { fs } = fb;

let chwToken: string;
let key: Buffer;
let deviceId: string;
let fields: AlertFields;

beforeAll(async () => {
  await clearEmulators();
  await centre('hc-a');
  await chw('chw-a', 'hc-a', PHONE);
  await chw('chw-b', 'hc-a', '+250780000402');
  for (const code of ['HB', 'CV']) {
    await fs.collection('dangerSigns').doc(code).set({ visitType: 'maternal', labelEn: code, labelRw: code });
  }
  chwToken = bearer(await idToken('chw-a'));
  const res = await request(app).post('/devices/register').set('authorization', chwToken).send({ buildFlavor: 'managed' }).expect(201);
  deviceId = res.body.deviceId;
  key = Buffer.from(res.body.smsKey, 'base64');
});

// Each test gets its own case code and patient, so they do not see each other's cases.
beforeEach(() => {
  const id = randomUUID();
  fields = {
    shortCode: id.slice(0, 8),
    patient: `P${randomBytes(3).toString('hex').toUpperCase()}`,
    type: 'M',
    time: '2610062114',
    signs: ['HB', 'CV'],
    vitals: ['T389'],
  };
});

const post = (path: string, form: Record<string, string>, secret: string | null = SECRET) =>
  request(app).post(`/webhooks/sms${path}${secret ? `?secret=${secret}` : ''}`).type('form').send(form);
const sms = (f = fields, nonce = randomBytes(12)) => seal(key, deviceId, encodePlaintext(f), nonce);
const visitsFor = async (code: string) =>
  (await fs.collection('visits').where('deviceId', '==', deviceId).where('shortCode', '==', code).get()).docs;

describe('POST /devices/register', () => {
  it('issues an ID and a 32-byte key once, keeping the key wrapped in the server-only collection', async () => {
    expect(key).toHaveLength(32);
    expect(deviceId).toMatch(/^D\d{6}$/);
    expect((await fs.collection('devices').doc(deviceId).get()).data()).toMatchObject({ userId: 'chw-a', buildFlavor: 'managed' });
    const stored = (await fs.collection('deviceKeys').doc(deviceId).get()).data()!.smsKey;
    expect(Buffer.from(stored).toString('hex')).not.toContain(key.toString('hex'));
    expect(unwrapKey(stored).equals(key)).toBe(true);
  });

  it('requires a CHW and a valid flavour', async () => {
    await request(app).post('/devices/register').send({ buildFlavor: 'store' }).expect(401);
    await request(app).post('/devices/register').set('authorization', chwToken).send({ buildFlavor: 'beta' }).expect(400);
  });
});

describe('POST /webhooks/sms', () => {
  it('rejects a wrong or missing secret', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text }, 'wrong-secret-wrong!').expect(401);
    await post('', { from: PHONE, text }, null).expect(401);
  });

  it('turns a valid SMS into a partial urgent visit, a stub patient and an SMS alert, then sends a signed ack', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text }).expect(200);

    const [visit] = await visitsFor(fields.shortCode);
    expect(visit.data()).toMatchObject({
      chwId: 'chw-a',
      healthCenterId: 'hc-a',
      type: 'maternal',
      source: 'sms',
      isPartial: true,
      isUrgent: true,
      dangerSigns: ['HB', 'CV'],
    });
    expect((visit.data().recordedAt as Timestamp).toDate()).toEqual(new Date('2026-10-06T19:14:00Z')); // 21:14 Kigali
    const patient = (await fs.collection('patients').doc(visit.data().patientId).get()).data();
    expect(patient).toMatchObject({ shortId: fields.patient, fullName: STUB_PATIENT_NAME, chwId: 'chw-a' });
    expect((await fs.collection('alerts').doc(visit.id).get()).data()).toMatchObject({ channel: 'sms', status: 'new', healthCenterId: 'hc-a' });
    expect(sender.sent.at(-1)).toEqual({ to: PHONE, text: `HB OK ${fields.shortCode} ${ackTag(key, fields.shortCode)}` });
  });

  it('refuses a replayed SMS and stores the case once', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text }).expect(200);
    await post('', { from: PHONE, text }).expect(200);
    expect(await visitsFor(fields.shortCode)).toHaveLength(1);
    const replay = await fs.collection('smsMessages').where('error', '==', 'replay').get();
    expect(replay.docs.some((d) => d.data().rawText === text)).toBe(true);
  });

  it('reassembles a two-part SMS in either order', async () => {
    // Add vitals until the sealed alert no longer fits one SMS.
    const long = { ...fields, vitals: [...fields.vitals] };
    while (sms(long).length < 2) long.vitals.push(`V${100 + long.vitals.length}`);
    const parts = sms(long);
    expect(parts).toHaveLength(2);
    await post('', { from: PHONE, text: parts[1] }).expect(200);
    expect(await visitsFor(long.shortCode)).toHaveLength(0);
    await post('', { from: PHONE, text: parts[0] }).expect(200);
    expect(await visitsFor(long.shortCode)).toHaveLength(1);
  });

  it('keeps the alert when the ack cannot be sent', async () => {
    sender.fail = true;
    const [text] = sms();
    await post('', { from: PHONE, text }).expect(200);
    sender.fail = false;
    expect(await visitsFor(fields.shortCode)).toHaveLength(1);
    const failed = await fs.collection('smsMessages').where('direction', '==', 'out').where('status', '==', 'failed').get();
    expect(failed.size).toBeGreaterThan(0);
  });

  it('rejects unknown devices and other CHWs\' patients without storing a case', async () => {
    const [unknown] = seal(key, 'D999999', encodePlaintext(fields), randomBytes(12));
    await post('', { from: PHONE, text: unknown }).expect(200);
    // Another CHW's patient with the same short ID.
    await fs.collection('patients').doc(randomUUID()).set({ shortId: fields.patient, chwId: 'chw-b', fullName: 'X' });
    const [text] = sms();
    await post('', { from: PHONE, text }).expect(200);
    expect(await visitsFor(fields.shortCode)).toHaveLength(0);
  });
});

describe('POST /visits/:id/merge-sms (FR-14)', () => {
  it('folds the SMS case into the full visit: one visit, one alert with its history, no stub patient', async () => {
    const [text] = sms();
    await post('', { from: PHONE, text }).expect(200);
    const [partial] = await visitsFor(fields.shortCode);
    const stubId = partial.data().patientId;
    await fs.collection('alerts').doc(partial.id).collection('events').add({ toStatus: 'reviewed', createdAt: Timestamp.now() });

    // The phone uploads the real patient and the full visit (as it does through Firestore).
    const patientId = randomUUID();
    const visitId = `${fields.shortCode}${randomUUID().slice(8)}`;
    await fs.collection('patients').doc(patientId).set({ shortId: `${fields.patient}X`, chwId: 'chw-a', fullName: 'Uwase Marie' });
    await fs.collection('visits').doc(visitId).set({
      shortCode: fields.shortCode,
      patientId,
      chwId: 'chw-a',
      healthCenterId: 'hc-a',
      deviceId,
      isPartial: false,
      isUrgent: true,
    });

    const res = await request(app).post(`/visits/${visitId}/merge-sms`).set('authorization', chwToken).expect(200);
    expect(res.body).toEqual({ merged: true });
    expect((await visitsFor(fields.shortCode)).map((v) => v.id)).toEqual([visitId]);
    expect((await fs.collection('alerts').doc(partial.id).get()).exists).toBe(false);
    const alert = fs.collection('alerts').doc(visitId);
    expect((await alert.get()).data()).toMatchObject({ visitId, channel: 'sms' });
    expect((await alert.collection('events').get()).size).toBe(1);
    expect((await fs.collection('patients').doc(stubId).get()).exists).toBe(false);

    // Calling again changes nothing.
    expect((await request(app).post(`/visits/${visitId}/merge-sms`).set('authorization', chwToken).expect(200)).body).toEqual({
      merged: false,
    });
  });

  it('only the visit\'s own CHW can merge it', async () => {
    const visitId = randomUUID();
    await fs.collection('visits').doc(visitId).set({ shortCode: visitId.slice(0, 8), chwId: 'chw-a', deviceId, isPartial: false });
    const other = bearer(await idToken('chw-b'));
    await request(app).post(`/visits/${visitId}/merge-sms`).set('authorization', other).expect(404);
  });
});

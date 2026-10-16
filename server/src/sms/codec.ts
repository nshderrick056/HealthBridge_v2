// Urgent-alert SMS codec (Backend Schema §3). Must stay byte-identical to lib/core/sms/codec.dart;
// shared/sms-vectors.json is checked by both test suites.
//
//   one part:  HB1 <device> <base64(nonce[12] | ciphertext | tag[16])>
//   two parts: HB1 <device> 1/2 <first half of base64>   and   HB1 <device> 2/2 <second half>
//
// AES-256-GCM with the header "HB1 <device>" as associated data, so a body cannot be re-sent under
// another device ID.
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

export const SMS_MAX = 160;
const VERSION = 'HB1';
const NONCE_LEN = 12;
const TAG_LEN = 16;

export type VisitLetter = 'M' | 'C' | 'L' | 'N';

export type AlertFields = {
  shortCode: string; // first 8 hex of the visit UUID
  patient: string; // patient short ID, never a name
  type: VisitLetter;
  time: string; // YYMMDDHHmm, phone time
  signs: string[]; // danger-sign codes
  vitals: string[]; // e.g. T389, G32
};

const ID = /^[A-Z0-9]{2,10}$/;
const SHORT_CODE = /^[0-9a-f]{8}$/;
const TIME = /^\d{10}$/;
const SIGN = /^[A-Z]{2}$/;
const VITAL = /^[A-Z][0-9.]{1,6}$/;
const SMS_RE = /^HB1 ([A-Z0-9]{2,10}) (?:([12])\/2 )?([A-Za-z0-9+/=]+)$/;

export class CodecError extends Error {}

function check(ok: boolean, what: string): asserts ok {
  if (!ok) throw new CodecError(`invalid ${what}`);
}

function checkFields(f: AlertFields) {
  check(SHORT_CODE.test(f.shortCode), 'short code');
  check(ID.test(f.patient), 'patient');
  check(['M', 'C', 'L', 'N'].includes(f.type), 'visit type');
  check(TIME.test(f.time), 'time');
  check(f.signs.every((s) => SIGN.test(s)), 'sign');
  check(f.vitals.every((v) => VITAL.test(v)), 'vital');
}

export function encodePlaintext(f: AlertFields): string {
  checkFields(f);
  return ['A', f.shortCode, f.patient, f.type, f.time, f.signs.join(','), ...f.vitals].join(';');
}

export function decodePlaintext(text: string): AlertFields {
  const [kind, shortCode, patient, type, time, signs, ...vitals] = text.split(';');
  check(kind === 'A' && signs !== undefined, 'plaintext');
  const f: AlertFields = {
    shortCode,
    patient,
    type: type as VisitLetter,
    time,
    signs: signs === '' ? [] : signs.split(','),
    vitals,
  };
  checkFields(f);
  return f;
}

/** Encrypts and splits into one or two SMS texts of at most 160 characters each. */
export function seal(key: Buffer, deviceId: string, plaintext: string, nonce = randomBytes(NONCE_LEN)): string[] {
  check(key.length === 32, 'key');
  check(nonce.length === NONCE_LEN, 'nonce');
  check(ID.test(deviceId), 'device');
  const header = `${VERSION} ${deviceId}`;
  const cipher = createCipheriv('aes-256-gcm', key, nonce, { authTagLength: TAG_LEN });
  cipher.setAAD(Buffer.from(header, 'utf8'));
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const body = Buffer.concat([nonce, ct, cipher.getAuthTag()]).toString('base64');

  const single = `${header} ${body}`;
  if (single.length <= SMS_MAX) return [single];
  const half = Math.ceil(body.length / 2);
  const parts = [body.slice(0, half), body.slice(half)].map((p, i) => `${header} ${i + 1}/2 ${p}`);
  check(parts.every((p) => p.length <= SMS_MAX), 'length (payload too long for two SMS)');
  return parts;
}

export type ParsedSms = { deviceId: string; part: 1 | 2 | null; body: string };

/** Reads the clear header so the server can pick the device key. Null if it is not a HealthBridge SMS. */
export function parseSms(text: string): ParsedSms | null {
  const m = SMS_RE.exec(text.trim());
  if (!m) return null;
  return { deviceId: m[1], part: m[2] ? (Number(m[2]) as 1 | 2) : null, body: m[3] };
}

/** Reassembles (parts may arrive in any order), verifies and decrypts. Throws CodecError on any mismatch. */
export function openSms(key: Buffer, texts: string[]): { deviceId: string; nonce: Buffer; plaintext: string } {
  check(key.length === 32, 'key');
  const parts = texts.map(parseSms);
  check(parts.length > 0 && parts.every((p) => p !== null), 'sms');
  const ps = parts as ParsedSms[];
  const deviceId = ps[0].deviceId;
  check(ps.every((p) => p.deviceId === deviceId), 'device');

  let body: string;
  if (ps.length === 1 && ps[0].part === null) {
    body = ps[0].body;
  } else {
    check(ps.length === 2, 'part count');
    const [a, b] = [...ps].sort((x, y) => (x.part ?? 0) - (y.part ?? 0));
    check(a.part === 1 && b.part === 2, 'parts');
    body = a.body + b.body;
  }

  const raw = Buffer.from(body, 'base64');
  check(raw.toString('base64') === body && raw.length > NONCE_LEN + TAG_LEN, 'body');
  const nonce = raw.subarray(0, NONCE_LEN);
  const decipher = createDecipheriv('aes-256-gcm', key, nonce, { authTagLength: TAG_LEN });
  decipher.setAAD(Buffer.from(`${VERSION} ${deviceId}`, 'utf8'));
  decipher.setAuthTag(raw.subarray(raw.length - TAG_LEN));
  try {
    const plaintext = Buffer.concat([
      decipher.update(raw.subarray(NONCE_LEN, raw.length - TAG_LEN)),
      decipher.final(),
    ]).toString('utf8');
    return { deviceId, nonce: Buffer.from(nonce), plaintext };
  } catch {
    throw new CodecError('authentication failed');
  }
}

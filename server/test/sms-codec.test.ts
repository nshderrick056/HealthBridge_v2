import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { CodecError, SMS_MAX, ackTag, decodePlaintext, encodePlaintext, openSms, parseSms, seal } from '../src/sms/codec';

// Same vector as test/core/sms/codec_test.dart, so the server's tag and the phone's check agree.
describe('ack tag', () => {
  it('is the first 12 hex of HMAC-SHA256 over "HB OK <code>" with the device key', () => {
    const key = Buffer.from('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', 'hex');
    expect(ackTag(key, '7f3c9a21')).toBe('8390abb11a59');
    expect(ackTag(key, '7f3c9a22')).not.toBe('8390abb11a59');
  });
});

// Shared with test/core/sms/codec_test.dart: both languages must produce and accept exactly these.
const vectors = JSON.parse(readFileSync(new URL('../../shared/sms-vectors.json', import.meta.url), 'utf8'));
const key = Buffer.from(vectors.key, 'hex');

describe('shared vectors', () => {
  for (const v of vectors.valid) {
    it(`seals and opens: ${v.name}`, () => {
      expect(encodePlaintext(v.fields)).toBe(v.plaintext);
      expect(decodePlaintext(v.plaintext)).toEqual(v.fields);

      const sms = seal(key, v.deviceId, v.plaintext, Buffer.from(v.nonce, 'hex'));
      expect(sms).toEqual(v.sms);
      sms.forEach((s: string) => expect(s.length).toBeLessThanOrEqual(SMS_MAX));

      const opened = openSms(key, [...v.sms].reverse()); // parts may arrive out of order
      expect(opened).toEqual({ deviceId: v.deviceId, nonce: Buffer.from(v.nonce, 'hex'), plaintext: v.plaintext });
    });
  }

  for (const r of vectors.rejected) {
    it(`rejects: ${r.name}`, () => {
      expect(() => openSms(key, r.sms)).toThrow(CodecError);
    });
  }

  it('rejects malformed plaintext', () => {
    for (const p of vectors.badPlaintext) expect(() => decodePlaintext(p), p).toThrow(CodecError);
  });
});

describe('codec', () => {
  it('uses a fresh random nonce by default', () => {
    const [a] = seal(key, 'D0042', vectors.valid[0].plaintext);
    const [b] = seal(key, 'D0042', vectors.valid[0].plaintext);
    expect(a).not.toBe(b);
  });

  it('fails with the wrong key', () => {
    expect(() => openSms(Buffer.alloc(32, 7), vectors.valid[0].sms)).toThrow(CodecError);
  });

  it('refuses payloads too long for two SMS', () => {
    expect(() => seal(key, 'D0042', 'A;'.padEnd(300, 'x'))).toThrow(CodecError);
  });

  it('parses the clear header', () => {
    expect(parseSms(vectors.valid[2].sms[1])).toMatchObject({ deviceId: 'D0042', part: 2 });
    expect(parseSms('HB OK 7f3c9a21')).toBeNull();
  });
});

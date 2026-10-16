import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { CodecError, SMS_MAX, decodePlaintext, encodePlaintext, openSms, parseSms, seal } from '../src/sms/codec';

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

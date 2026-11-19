// Device SMS keys are stored wrapped with AES-256-GCM: nonce[12] | ciphertext | tag[16].
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { env } from '../env';

const kek = () => Buffer.from(env.SMS_KEY_ENC_KEY, 'hex');

export function wrapKey(key: Buffer): Buffer {
  const nonce = randomBytes(12);
  const c = createCipheriv('aes-256-gcm', kek(), nonce);
  return Buffer.concat([nonce, c.update(key), c.final(), c.getAuthTag()]);
}

export function unwrapKey(stored: Uint8Array): Buffer {
  const b = Buffer.from(stored);
  const d = createDecipheriv('aes-256-gcm', kek(), b.subarray(0, 12));
  d.setAuthTag(b.subarray(b.length - 16));
  return Buffer.concat([d.update(b.subarray(12, b.length - 16)), d.final()]);
}

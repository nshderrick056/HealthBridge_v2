import { randomBytes, randomInt } from 'node:crypto';
import { Router } from 'express';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Fb } from '../firebase';
import { HttpError } from '../http';
import { callerOf, requireRole, requireUser } from '../middleware/auth';
import { wrapKey } from '../sms/keystore';

const body = z.object({
  buildFlavor: z.enum(['store', 'managed']),
  simPhone: z.string().min(6).max(20).optional(),
});

/** Firestore's error code for "document already exists" (gRPC ALREADY_EXISTS). */
export const isAlreadyExists = (e: unknown) => (e as { code?: number })?.code === 6;

export function devicesRouter(fb: Fb) {
  const router = Router();

  // The key is returned once, here, and kept wrapped in the server-only `deviceKeys`.
  // Registering again issues a new device and key.
  router.post('/register', requireUser(fb), requireRole('chw'), async (req, res) => {
    const { buildFlavor, simPhone } = body.parse(req.body);
    const { uid } = callerOf(res);
    const key = randomBytes(32);
    for (let attempt = 0; attempt < 5; attempt++) {
      const id = `D${randomInt(1_000_000).toString().padStart(6, '0')}`;
      try {
        const batch = fb.fs.batch();
        batch.create(fb.fs.collection('devices').doc(id), {
          userId: uid,
          buildFlavor,
          simPhone: simPhone ?? null,
          lastSyncAt: null,
          revokedAt: null,
          createdAt: FieldValue.serverTimestamp(),
        });
        batch.create(fb.fs.collection('deviceKeys').doc(id), { smsKey: wrapKey(key) });
        await batch.commit();
        res.status(201).json({ deviceId: id, smsKey: key.toString('base64') });
        return;
      } catch (e) {
        if (!isAlreadyExists(e)) throw e;
      }
    }
    throw new HttpError(503, 'device_id_unavailable');
  });

  return router;
}

import { randomBytes, randomInt } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import type { AccessClaims } from '../auth/tokens';
import type { Db } from '../db';
import { HttpError } from '../http';
import { requireAuth, requireRole } from '../middleware/auth';
import { wrapKey } from '../sms/keystore';

const body = z.object({
  buildFlavor: z.enum(['store', 'managed']),
  simPhone: z.string().min(6).max(20).optional(),
});

export const isUniqueViolation = (e: unknown) => (e as { code?: string })?.code === 'P2002';

export function devicesRouter(db: Db) {
  const router = Router();

  // The key is returned once, here. Registering again issues a new device and key.
  router.post('/register', requireAuth, requireRole('chw'), async (req, res) => {
    const { buildFlavor, simPhone } = body.parse(req.body);
    const { sub } = res.locals.auth as AccessClaims;
    const key = randomBytes(32);
    for (let attempt = 0; attempt < 5; attempt++) {
      const id = `D${randomInt(1_000_000).toString().padStart(6, '0')}`;
      try {
        await db.devices.create({
          data: { id, user_id: sub, sms_key: new Uint8Array(wrapKey(key)), sim_phone: simPhone, build_flavor: buildFlavor },
        });
        res.status(201).json({ deviceId: id, smsKey: key.toString('base64') });
        return;
      } catch (e) {
        if (!isUniqueViolation(e)) throw e;
      }
    }
    throw new HttpError(503, 'device_id_unavailable');
  });

  return router;
}

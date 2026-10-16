import { hash, verify } from '@node-rs/argon2';
import { Router } from 'express';
import { z } from 'zod';
import type { Db } from '../db';
import { HttpError } from '../http';
import { signAccess, signRefresh, verifyRefresh, type AccessClaims } from './tokens';

const loginBody = z.union([
  z.object({ phone: z.string().min(6).max(20), pin: z.string().regex(/^\d{4,6}$/) }),
  z.object({ email: z.email(), password: z.string().min(8).max(200) }),
]);
const refreshBody = z.object({ refreshToken: z.string().min(1) });

export const MAX_FAILED_LOGINS = 5;
export const LOCK_MS = 15 * 60_000;

// Unknown accounts still pay for one argon2 verify, so response time does not reveal which phones exist.
const dummyHash = hash('no-such-user');

type UserRow = {
  id: string;
  role: AccessClaims['role'];
  full_name: string;
  health_center_id: string | null;
  language: string;
};

const claims = (u: UserRow): AccessClaims => ({ sub: u.id, role: u.role, hc: u.health_center_id });

const publicUser = (u: UserRow) => ({
  id: u.id,
  role: u.role,
  fullName: u.full_name,
  healthCenterId: u.health_center_id,
  language: u.language,
});

const unauthorized = () => new HttpError(401, 'invalid_credentials');

export function authRouter(db: Db) {
  const router = Router();

  router.post('/login', async (req, res) => {
    const body = loginBody.parse(req.body);
    const [where, secret] =
      'phone' in body ? [{ phone: body.phone }, body.pin] : [{ email: body.email }, body.password];

    const user = await db.users.findFirst({ where: { ...where, active: true } });
    if (!user) {
      await verify(await dummyHash, secret);
      throw unauthorized();
    }
    if (user.locked_until && user.locked_until > new Date()) {
      throw new HttpError(429, 'too_many_attempts');
    }

    if (!(await verify(user.secret_hash, secret))) {
      const locks = user.failed_logins + 1 >= MAX_FAILED_LOGINS;
      await db.users.update({
        where: { id: user.id },
        data: locks
          ? { failed_logins: 0, locked_until: new Date(Date.now() + LOCK_MS) }
          : { failed_logins: { increment: 1 } },
      });
      throw unauthorized();
    }

    if (user.failed_logins > 0 || user.locked_until) {
      await db.users.update({ where: { id: user.id }, data: { failed_logins: 0, locked_until: null } });
    }
    res.json({
      accessToken: signAccess(claims(user)),
      refreshToken: signRefresh(user.id),
      user: publicUser(user),
    });
  });

  router.post('/refresh', async (req, res) => {
    const { refreshToken } = refreshBody.parse(req.body);
    let sub: string;
    try {
      sub = verifyRefresh(refreshToken);
    } catch {
      throw new HttpError(401, 'invalid_token');
    }
    // Re-read the user so deactivated accounts lose access within one access-token lifetime.
    const user = await db.users.findFirst({ where: { id: sub, active: true } });
    if (!user) throw new HttpError(401, 'invalid_token');
    res.json({ accessToken: signAccess(claims(user)) });
  });

  return router;
}

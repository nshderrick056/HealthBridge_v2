// Admin-only account management: health centres and the people who log in (there is no self sign-up).
import { hash } from '@node-rs/argon2';
import { Router } from 'express';
import { z } from 'zod';
import type { AccessClaims } from '../auth/tokens';
import type { Db } from '../db';
import { isUniqueViolation } from '../devices/routes';
import { HttpError } from '../http';
import { requireAuth, requireRole } from '../middleware/auth';

const phone = z.string().regex(/^\+?\d{9,15}$/, 'phone must be digits, optionally with a leading +');
const person = {
  fullName: z.string().trim().min(2).max(200),
  phone,
  healthCenterId: z.uuid(),
  language: z.enum(['rw', 'en']).default('rw'),
};
const userBody = z.discriminatedUnion('role', [
  // CHWs log in on the phone with phone + PIN.
  z.object({
    role: z.literal('chw'),
    ...person,
    pin: z.string().regex(/^\d{4,6}$/),
    chwRole: z.enum(['asm', 'binome']),
    village: z.string().trim().min(1).max(200),
  }),
  // Supervisors log in on the dashboard with email + password.
  z.object({
    role: z.literal('supervisor'),
    ...person,
    email: z.email(),
    password: z.string().min(8).max(200),
  }),
]);
const centreBody = z.object({
  name: z.string().trim().min(2).max(200),
  district: z.string().trim().min(1).max(100),
  sector: z.string().trim().min(1).max(100),
  callNumber: phone.optional(),
});

export function adminRouter(db: Db) {
  const router = Router();
  router.use(requireAuth, requireRole('admin'));

  const audit = (actor: string, action: string, entity: string, id: string) =>
    db.audit_log.create({ data: { actor_id: actor, action, entity, entity_id: id } });

  router.post('/health-centers', async (req, res) => {
    const b = centreBody.parse(req.body);
    const { sub } = res.locals.auth as AccessClaims;
    const centre = await db.health_centers.create({
      data: { name: b.name, district: b.district, sector: b.sector, call_number: b.callNumber },
    });
    await audit(sub, 'health_center.create', 'health_centers', centre.id);
    res.status(201).json({ id: centre.id, name: centre.name });
  });

  router.post('/users', async (req, res) => {
    const b = userBody.parse(req.body);
    const { sub } = res.locals.auth as AccessClaims;
    const centre = await db.health_centers.findUnique({ where: { id: b.healthCenterId } });
    if (!centre) throw new HttpError(400, 'unknown_health_center');

    try {
      const user = await db.users.create({
        data: {
          role: b.role,
          full_name: b.fullName,
          phone: b.phone,
          health_center_id: b.healthCenterId,
          language: b.language,
          ...(b.role === 'chw'
            ? { secret_hash: await hash(b.pin), chw_role: b.chwRole, village: b.village }
            : { secret_hash: await hash(b.password), email: b.email }),
        },
      });
      await audit(sub, 'user.create', 'users', user.id);
      res.status(201).json({ id: user.id, role: user.role, fullName: user.full_name });
    } catch (e) {
      if (isUniqueViolation(e)) throw new HttpError(409, 'phone_or_email_taken');
      throw e;
    }
  });

  return router;
}

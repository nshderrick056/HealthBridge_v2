// Urgent pathway, internet channel (TRD §5 step 2). The phone posts the urgent visit here first and
// only falls back to SMS when this fails or takes over 10 s. Idempotent by visit UUID, and shares the
// /sync/push upserts, so a retry, a later sync or an earlier SMS all end up as one visit and one alert.
import { Router } from 'express';
import { z, ZodError } from 'zod';
import type { AccessClaims } from '../auth/tokens';
import type { Db } from '../db';
import { HttpError } from '../http';
import { requireAuth, requireRole } from '../middleware/auth';
import { deviceContext, Rejected, upsertPatient, upsertVisit, visitPayload } from '../sync/routes';

const alertBody = z.object({
  deviceId: z.string().min(1).max(20),
  visit: z.unknown(),
  // The patient may still be in the phone's outbox (registered offline minutes ago), so it can ride along.
  patient: z.unknown().optional(),
});

/** POST /alerts for CHWs. Mounted under /alerts next to the supervisor routes, so the guards are per route. */
export function chwAlertsRouter(db: Db) {
  const router = Router();

  router.post('/', requireAuth, requireRole('chw'), async (req, res) => {
    const body = alertBody.parse(req.body);
    const visit = visitPayload.parse(body.visit);
    if (!visit.is_urgent) throw new HttpError(400, 'not_urgent');
    const { sub } = res.locals.auth as AccessClaims;
    const ctx = await deviceContext(db, sub, body.deviceId);
    if (!ctx.healthCenterId) throw new HttpError(409, 'no_health_center');

    try {
      const alert = await db.$transaction(async (tx) => {
        if (body.patient !== undefined) await upsertPatient(tx, ctx, body.patient);
        await upsertVisit(tx, ctx, visit);
        return tx.alerts.findUniqueOrThrow({ where: { visit_id: visit.id } });
      });
      res.json({
        alert: { id: alert.id, visit_id: alert.visit_id, channel: alert.channel, status: alert.status },
      });
    } catch (e) {
      if (e instanceof Rejected) throw new HttpError(409, e.message);
      if (e instanceof ZodError) throw new HttpError(400, 'invalid_patient');
      throw e;
    }
  });

  return router;
}

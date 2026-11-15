// Admin-only: health centres, accounts (there is no self sign-up), and approving reset requests.
import { randomInt } from 'node:crypto';
import { hash } from '@node-rs/argon2';
import { Router } from 'express';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { accountInput, audit, createAccount, phone, type UserDoc } from '../accounts';
import type { Fb } from '../firebase';
import { HttpError } from '../http';
import { callerOf, requireRole, requireUser } from '../middleware/auth';
import type { SmsSender } from '../sms/gateway';

const centreBody = z.object({
  name: z.string().trim().min(2).max(200),
  district: z.string().trim().min(1).max(100),
  sector: z.string().trim().min(1).max(100),
  callNumber: phone.optional(),
});

/** How long an approved reset code stays valid. */
export const RESET_CODE_MS = 30 * 60_000;

export function adminRouter(fb: Fb, sender: SmsSender) {
  const router = Router();
  router.use(requireUser(fb), requireRole('admin'));

  router.post('/health-centers', async (req, res) => {
    const b = centreBody.parse(req.body);
    const ref = await fb.fs.collection('healthCenters').add({
      name: b.name,
      district: b.district,
      sector: b.sector,
      callNumber: b.callNumber ?? null,
    });
    await audit(fb, callerOf(res).uid, 'health_center.create', 'healthCenters', ref.id);
    res.status(201).json({ id: ref.id, name: b.name });
  });

  router.post('/users', async (req, res) => {
    const b = accountInput.parse(req.body);
    const id = await createAccount(fb, b);
    await audit(fb, callerOf(res).uid, 'user.create', 'users', id);
    res.status(201).json({ id, role: b.role, fullName: b.fullName });
  });

  /** Reset requests waiting for an admin, oldest first. */
  router.get('/reset-requests', async (_req, res) => {
    const snap = await fb.fs.collection('resetRequests').where('status', '==', 'pending').get();
    const requests = await Promise.all(
      snap.docs.map(async (d) => {
        const r = d.data();
        const user = (await fb.fs.collection('users').doc(r.userId).get()).data() as UserDoc | undefined;
        return {
          id: d.id,
          userId: r.userId,
          name: user?.fullName ?? null,
          phone: user?.phone ?? null,
          role: user?.role ?? null,
          createdAt: (r.createdAt as Timestamp | undefined)?.toDate().toISOString() ?? null,
        };
      }),
    );
    requests.sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? ''));
    res.json({ requests });
  });

  /** Approves a request: a one-time code is texted to the user's phone. The admin never sees it. */
  router.post('/reset-requests/:id/approve', async (req, res) => {
    const ref = fb.fs.collection('resetRequests').doc(z.string().min(1).parse(req.params.id));
    const snap = await ref.get();
    if (!snap.exists) throw new HttpError(404, 'not_found');
    const r = snap.data()!;
    if (r.status !== 'pending') throw new HttpError(409, 'not_pending');
    const user = (await fb.fs.collection('users').doc(r.userId).get()).data() as UserDoc | undefined;
    if (!user?.active) throw new HttpError(409, 'user_inactive');

    const code = randomInt(1_000_000).toString().padStart(6, '0');
    try {
      await sender.send(user.phone, `HealthBridge: your reset code is ${code}. It expires in 30 minutes.`);
    } catch {
      // Nothing is stored, so the admin can simply approve again once SMS works.
      throw new HttpError(502, 'sms_failed');
    }
    await ref.update({
      status: 'approved',
      codeHash: await hash(code),
      attempts: 0,
      approvedBy: callerOf(res).uid,
      expiresAt: Timestamp.fromMillis(Date.now() + RESET_CODE_MS),
      approvedAt: FieldValue.serverTimestamp(),
    });
    await audit(fb, callerOf(res).uid, 'reset.approve', 'resetRequests', ref.id);
    res.json({ id: ref.id, status: 'approved' });
  });

  return router;
}

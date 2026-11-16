// Admin-only: health centres, accounts (there is no self sign-up), and approving reset requests.
import { randomBytes, randomInt } from 'node:crypto';
import { hash } from '@node-rs/argon2';
import { Router } from 'express';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { type AccountInput, audit, createAccount, newAccountInput, phone, type UserDoc } from '../accounts';
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

  /** For the new-account form's health centre picker, by name. */
  router.get('/health-centers', async (_req, res) => {
    const snap = await fb.fs.collection('healthCenters').get();
    const centres = snap.docs.map((d) => ({ id: d.id, name: d.data().name as string, district: d.data().district ?? null }));
    centres.sort((a, b) => a.name.localeCompare(b.name));
    res.json({ centres });
  });

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

  /**
   * The server makes a temporary PIN (CHW) and/or password (with an email) and texts them to the new
   * user, who must set their own at first sign-in. The admin never sees them.
   */
  router.post('/users', async (req, res) => {
    const b = newAccountInput.parse(req.body);
    const pin = b.role === 'chw' ? randomInt(1_000_000).toString().padStart(6, '0') : undefined;
    const password = b.email ? randomBytes(9).toString('base64url') : undefined;
    const id = await createAccount(fb, { ...b, pin, password } as AccountInput, undefined, true);
    await audit(fb, callerOf(res).uid, 'user.create', 'users', id);

    const parts = [
      pin && `PIN ${pin}`,
      password && `email ${b.email} and password ${password}`,
    ].filter(Boolean);
    let smsSent = true;
    try {
      await sender.send(
        b.phone,
        `HealthBridge: your account is ready. Sign in with ${parts.join(', or ')}. You will then choose your own.`,
      );
    } catch {
      // The account stands; the user can still get in through Forgot PIN/password.
      smsSent = false;
    }
    res.status(201).json({ id, role: b.role, fullName: b.fullName, smsSent });
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

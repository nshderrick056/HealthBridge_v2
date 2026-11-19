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

  /** A member (CHW or supervisor) as the admin pages show them. */
  const memberJson = (id: string, u: FirebaseFirestore.DocumentData) => ({
    id,
    role: u.role as string,
    fullName: u.fullName as string,
    phone: u.phone as string,
    email: (u.email as string | null) ?? null,
    chwRole: (u.chwRole as string | null) ?? null,
    village: (u.village as string | null) ?? null,
    healthCenterId: (u.healthCenterId as string | null) ?? null,
    active: u.active !== false,
    createdAt: (u.createdAt as Timestamp | undefined)?.toDate().toISOString() ?? null,
  });

  const members = ['chw', 'supervisor'] as const;
  const idParam = z.string().min(1).max(128);

  /** Admins manage CHWs and supervisors only; an admin account is never changed or deleted here. */
  async function member(id: unknown) {
    const ref = fb.fs.collection('users').doc(idParam.parse(id));
    const data = (await ref.get()).data();
    if (!data || !members.includes(data.role)) throw new HttpError(404, 'not_found');
    return { ref, data };
  }

  /** CHWs or supervisors, by name, each with the name of their health centre. */
  router.get('/users', async (req, res) => {
    const role = z.enum(members).parse(req.query.role);
    const [users, centres] = await Promise.all([
      fb.fs.collection('users').where('role', '==', role).get(),
      fb.fs.collection('healthCenters').get(),
    ]);
    const names = new Map(centres.docs.map((c) => [c.id, c.data().name as string]));
    const list = users.docs
      .map((d) => ({ ...memberJson(d.id, d.data()), healthCenterName: names.get(d.data().healthCenterId) ?? null }))
      .sort((a, b) => a.fullName.localeCompare(b.fullName));
    res.json({ members: list });
  });

  router.get('/users/:id', async (req, res) => {
    const { ref, data } = await member(req.params.id);
    const hc = data.healthCenterId ? (await fb.fs.collection('healthCenters').doc(data.healthCenterId).get()).data() : null;
    res.json({ ...memberJson(ref.id, data), healthCenterName: (hc?.name as string) ?? null });
  });

  /** Switches an account off or on. Off: no PIN, SMS or password sign-in, and open sessions end at once. */
  router.patch('/users/:id', async (req, res) => {
    const { active } = z.object({ active: z.boolean() }).parse(req.body);
    const { ref } = await member(req.params.id);
    await ref.update({ active });
    await fb.auth.updateUser(ref.id, { disabled: !active });
    if (!active) await fb.auth.revokeRefreshTokens(ref.id);
    await audit(fb, callerOf(res).uid, active ? 'user.activate' : 'user.deactivate', 'users', ref.id);
    res.json({ id: ref.id, active });
  });

  /**
   * Deletes the account and its sign-in details and devices. The patients and visits they recorded stay:
   * health records are kept (their CHW then shows as unknown).
   */
  router.delete('/users/:id', async (req, res) => {
    const { ref } = await member(req.params.id);
    const devices = await fb.fs.collection('devices').where('userId', '==', ref.id).get();
    await fb.auth.deleteUser(ref.id).catch((e: { code?: string }) => {
      if (e.code !== 'auth/user-not-found') throw e;
    });
    const batch = fb.fs.batch();
    for (const d of devices.docs) batch.delete(d.ref);
    batch.delete(fb.fs.collection('credentials').doc(ref.id));
    batch.delete(ref);
    await batch.commit();
    await audit(fb, callerOf(res).uid, 'user.delete', 'users', ref.id);
    res.json({ id: ref.id, deleted: true });
  });

  /** A health centre with its details and the CHWs and supervisors who belong to it. */
  router.get('/health-centers/:id', async (req, res) => {
    const id = idParam.parse(req.params.id);
    const snap = await fb.fs.collection('healthCenters').doc(id).get();
    if (!snap.exists) throw new HttpError(404, 'not_found');
    const c = snap.data()!;
    const users = await fb.fs.collection('users').where('healthCenterId', '==', id).get();
    res.json({
      id,
      name: c.name as string,
      district: (c.district as string | null) ?? null,
      sector: (c.sector as string | null) ?? null,
      callNumber: (c.callNumber as string | null) ?? null,
      members: users.docs
        .map((d) => memberJson(d.id, d.data()))
        .filter((m) => m.role === 'chw' || m.role === 'supervisor')
        .sort((a, b) => a.fullName.localeCompare(b.fullName)),
    });
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

// Sign-in that Firebase cannot do by itself, and the admin-approved reset flow.
//   POST /auth/pin             phone + PIN -> a Firebase custom token (the app signs in with it)
//   POST /auth/reset/request   flags "forgot my PIN/password" for an admin
//   POST /auth/reset/verify    the texted code -> a 10-minute reset token
//   POST /auth/reset/complete  reset token + new PIN and/or password
// Email + password and phone + SMS code sign-in go straight to Firebase Auth from the app.
import { hash, verify } from '@node-rs/argon2';
import { Router } from 'express';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { audit, findUser, password, phone, pin } from '../accounts';
import { env } from '../env';
import type { Fb } from '../firebase';
import { HttpError } from '../http';

export const MAX_FAILED_LOGINS = 5;
export const LOCK_MS = 15 * 60_000;
/** Wrong codes allowed on one approved reset before it has to be approved again. */
export const MAX_CODE_ATTEMPTS = 5;
const RESET_TOKEN_TTL = '10m';

// Unknown accounts still pay for one argon2 verify, so response time does not reveal which phones exist.
const dummyHash = hash('no-such-user');
const unauthorized = () => new HttpError(401, 'invalid_credentials');

const pinBody = z.object({ phone, pin });
const who = z.union([z.object({ phone }), z.object({ email: z.email() })]);
const verifyBody = z.intersection(who, z.object({ code: z.string().regex(/^\d{6}$/) }));
const completeBody = z
  .object({ resetToken: z.string().min(1), pin: pin.optional(), password: password.optional() })
  .refine((b) => b.pin || b.password, 'give a new PIN or password');

export function authRouter(fb: Fb) {
  const router = Router();
  const credentials = fb.fs.collection('credentials');
  const resets = fb.fs.collection('resetRequests');

  router.post('/pin', async (req, res) => {
    const { phone: p, pin: given } = pinBody.parse(req.body);
    const user = await findUser(fb, { phone: p });
    const credRef = user && credentials.doc(user.id);
    const cred = credRef && (await credRef.get()).data();
    if (!user || !credRef || !cred?.pinHash) {
      await verify(await dummyHash, given);
      throw unauthorized();
    }
    if (cred.lockedUntil && (cred.lockedUntil as Timestamp).toMillis() > Date.now()) {
      throw new HttpError(429, 'too_many_attempts');
    }
    if (!(await verify(cred.pinHash, given))) {
      const locks = (cred.failedLogins ?? 0) + 1 >= MAX_FAILED_LOGINS;
      await credRef.update(
        locks
          ? { failedLogins: 0, lockedUntil: Timestamp.fromMillis(Date.now() + LOCK_MS) }
          : { failedLogins: FieldValue.increment(1) },
      );
      throw unauthorized();
    }
    if (cred.failedLogins || cred.lockedUntil) await credRef.update({ failedLogins: 0, lockedUntil: null });
    const claims = { role: user.role, hc: user.healthCenterId };
    res.json({ customToken: await fb.auth.createCustomToken(user.id, claims) });
  });

  // Always the same answer, so it cannot be used to find out which phones or emails have accounts.
  router.post('/reset/request', async (req, res) => {
    const by = who.parse(req.body);
    const user = await findUser(fb, by);
    if (user) {
      const open = await resets.where('userId', '==', user.id).where('status', 'in', ['pending', 'approved']).get();
      if (open.empty) {
        const ref = await resets.add({ userId: user.id, status: 'pending', attempts: 0, createdAt: FieldValue.serverTimestamp() });
        await audit(fb, user.id, 'reset.request', 'resetRequests', ref.id);
      }
    }
    res.json({ ok: true });
  });

  router.post('/reset/verify', async (req, res) => {
    const b = verifyBody.parse(req.body);
    const user = await findUser(fb, 'phone' in b ? { phone: b.phone } : { email: b.email });
    const snap = user && (await resets.where('userId', '==', user.id).where('status', '==', 'approved').limit(1).get());
    const doc = snap && !snap.empty ? snap.docs[0] : null;
    const r = doc?.data();
    if (!user || !doc || !r || (r.expiresAt as Timestamp).toMillis() < Date.now()) {
      await verify(await dummyHash, b.code);
      throw new HttpError(401, 'invalid_code');
    }
    if (!(await verify(r.codeHash, b.code))) {
      const attempts = (r.attempts ?? 0) + 1;
      // Too many wrong codes: the request is closed and the user has to ask again.
      await doc.ref.update(attempts >= MAX_CODE_ATTEMPTS ? { attempts, status: 'expired' } : { attempts });
      throw new HttpError(401, 'invalid_code');
    }
    await doc.ref.update({ status: 'verified' });
    const resetToken = jwt.sign({ sub: user.id, rid: doc.id, purpose: 'reset' }, env.JWT_SECRET, {
      expiresIn: RESET_TOKEN_TTL,
    });
    res.json({ resetToken });
  });

  router.post('/reset/complete', async (req, res) => {
    const b = completeBody.parse(req.body);
    let claims: { sub: string; rid: string; purpose: string };
    try {
      claims = jwt.verify(b.resetToken, env.JWT_SECRET) as typeof claims;
      if (claims.purpose !== 'reset') throw new Error('wrong token');
    } catch {
      throw new HttpError(401, 'invalid_token');
    }
    const ref = resets.doc(claims.rid);
    // Used once: the request moves from verified to used inside a transaction.
    await fb.fs.runTransaction(async (tx) => {
      const r = (await tx.get(ref)).data();
      if (!r || r.status !== 'verified' || r.userId !== claims.sub) throw new HttpError(401, 'invalid_token');
      tx.update(ref, { status: 'used', usedAt: FieldValue.serverTimestamp() });
    });
    if (b.pin) {
      await credentials
        .doc(claims.sub)
        .set({ pinHash: await hash(b.pin), failedLogins: 0, lockedUntil: null }, { merge: true });
    }
    if (b.password) {
      const account = await fb.auth.getUser(claims.sub);
      if (!account.email) throw new HttpError(400, 'no_email_on_account');
      await fb.auth.updateUser(claims.sub, { password: b.password });
    }
    // Anyone signed in with the old details is signed out.
    await fb.auth.revokeRefreshTokens(claims.sub);
    await audit(fb, claims.sub, 'reset.complete', 'resetRequests', ref.id);
    res.json({ ok: true });
  });

  return router;
}

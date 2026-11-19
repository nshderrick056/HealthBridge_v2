// Accounts are made only by an admin (there is no self sign-up; it is also switched off in Firebase Auth).
// One account = a Firebase Auth user + role claims + a `users` profile + (for a PIN) a server-only
// `credentials` document. Shared by POST /admin/users and the seed script.
import { hash } from '@node-rs/argon2';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Fb } from './firebase';
import { HttpError } from './http';
import type { Role } from './middleware/auth';

export const phone = z.string().regex(/^\+\d{9,15}$/, 'phone must be in international format, e.g. +2507...');
export const pin = z.string().regex(/^\d{4,6}$/, 'PIN must be 4 to 6 digits');
export const password = z.string().min(8, 'password must be at least 8 characters').max(200);

const person = {
  fullName: z.string().trim().min(2).max(200),
  phone,
  healthCenterId: z.string().min(1).max(100),
  language: z.enum(['rw', 'en']).default('rw'),
};

export const accountInput = z.discriminatedUnion('role', [
  // CHWs sign in on the phone: phone + PIN, or phone + SMS code; an email + password is optional.
  z
    .object({
      role: z.literal('chw'),
      ...person,
      pin,
      chwRole: z.enum(['asm', 'binome']),
      village: z.string().trim().min(1).max(200),
      email: z.email().optional(),
      password: password.optional(),
    })
    .refine((u) => !u.email === !u.password, 'email and password go together'),
  // Supervisors sign in with email + password (in the app and on the dashboard).
  z.object({ role: z.literal('supervisor'), ...person, email: z.email(), password, pin: pin.optional() }),
]);
export type AccountInput = z.infer<typeof accountInput>;

/** What the admin's form sends: no PIN or password, the server makes temporary ones and texts them. */
export const newAccountInput = z.discriminatedUnion('role', [
  z.object({
    role: z.literal('chw'),
    ...person,
    chwRole: z.enum(['asm', 'binome']),
    village: z.string().trim().min(1).max(200),
    email: z.email().optional(),
  }),
  z.object({ role: z.literal('supervisor'), ...person, email: z.email() }),
]);

/**
 * Creates the account; `uid` fixes the ID (the seed script uses stable ones). Returns the new user's ID.
 * `mustChange`: the PIN/password are temporary; the `mc` claim keeps the user on the change screen until
 * they set their own (POST /auth/change).
 */
export async function createAccount(fb: Fb, a: AccountInput, uid?: string, mustChange = false): Promise<string> {
  const centre = await fb.fs.collection('healthCenters').doc(a.healthCenterId).get();
  if (!centre.exists) throw new HttpError(400, 'unknown_health_center');

  let user;
  try {
    user = await fb.auth.createUser({
      ...(uid && { uid }),
      displayName: a.fullName,
      phoneNumber: a.phone,
      ...(a.email && { email: a.email, password: a.password, emailVerified: true }),
    });
  } catch (e) {
    const code = (e as { code?: string }).code ?? '';
    if (/phone-number-already-exists|email-already-exists|uid-already-exists/.test(code)) {
      throw new HttpError(409, 'phone_or_email_taken');
    }
    throw e;
  }
  const role: Role = a.role;
  // The rules read role and health centre from the sign-in token, so the user cannot change them.
  await fb.auth.setCustomUserClaims(user.uid, { role, hc: a.healthCenterId, ...(mustChange && { mc: true }) });

  const batch = fb.fs.batch();
  batch.set(fb.fs.collection('users').doc(user.uid), {
    role,
    chwRole: a.role === 'chw' ? a.chwRole : null,
    fullName: a.fullName,
    phone: a.phone,
    email: a.email ?? null,
    healthCenterId: a.healthCenterId,
    village: a.role === 'chw' ? a.village : null,
    language: a.language,
    active: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  if (a.pin) {
    batch.set(fb.fs.collection('credentials').doc(user.uid), {
      pinHash: await hash(a.pin),
      failedLogins: 0,
      lockedUntil: null,
    });
  }
  await batch.commit();
  return user.uid;
}

/** A system admin: email + password, no health centre. Made only by the create-admin and seed scripts. */
export async function createAdmin(
  fb: Fb,
  a: { fullName: string; phone: string; email: string; password: string },
  uid?: string,
): Promise<string> {
  const user = await fb.auth.createUser({
    ...(uid && { uid }),
    displayName: a.fullName,
    phoneNumber: a.phone,
    email: a.email,
    password: a.password,
    emailVerified: true,
  });
  await fb.auth.setCustomUserClaims(user.uid, { role: 'admin', hc: null });
  await fb.fs.collection('users').doc(user.uid).set({
    role: 'admin',
    chwRole: null,
    fullName: a.fullName,
    phone: a.phone,
    email: a.email,
    healthCenterId: null,
    village: null,
    language: 'en',
    active: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  return user.uid;
}

/** The user has set their own PIN/password: drops the `mc` claim (it leaves their next ID token). */
export async function clearMustChange(fb: Fb, uid: string) {
  const { mc, ...rest } = (await fb.auth.getUser(uid)).customClaims ?? {};
  if (mc) await fb.auth.setCustomUserClaims(uid, rest);
}

/** Records who did what; read only by the server and in the Firebase console. */
export const audit = (fb: Fb, actorId: string | null, action: string, entity: string, entityId: string) =>
  fb.fs.collection('auditLog').add({ actorId, action, entity, entityId, createdAt: FieldValue.serverTimestamp() });

/** Finds an active user by phone or email; null when there is none. */
export async function findUser(fb: Fb, by: { phone?: string; email?: string }) {
  const field = by.phone ? 'phone' : 'email';
  const value = by.phone ?? by.email;
  if (!value) return null;
  const snap = await fb.fs.collection('users').where(field, '==', value).where('active', '==', true).limit(1).get();
  return snap.empty ? null : { id: snap.docs[0].id, ...(snap.docs[0].data() as UserDoc) };
}

export type UserDoc = {
  role: Role;
  fullName: string;
  phone: string;
  email: string | null;
  healthCenterId: string | null;
  village: string | null;
  active: boolean;
};

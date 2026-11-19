// Shared setup for tests against the Firebase emulators (see vitest.config.ts).
import { createAccount, createAdmin, type AccountInput } from '../src/accounts';
import { createApp } from '../src/app';
import { createFirebase } from '../src/firebase';

const PROJECT = 'demo-healthbridge';
const fsHost = () => required('FIRESTORE_EMULATOR_HOST');
const authHost = () => required('FIREBASE_AUTH_EMULATOR_HOST');

function required(name: string) {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is not set: run the server tests with \`npm test\` (it starts the emulators)`);
  return v;
}

export const fb = createFirebase();

/** Empties the emulated Firestore and Auth. */
export async function clearEmulators() {
  await fetch(`http://${fsHost()}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${authHost()}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
}

/** A real ID token from the Auth emulator for [uid], carrying the user's custom claims. */
export async function idToken(uid: string, claims?: Record<string, unknown>) {
  return exchange(await fb.auth.createCustomToken(uid, claims));
}

/** Signs in with a custom token (as the app does after PIN sign-in) and returns the ID token. */
export async function exchange(customToken: string): Promise<string> {
  const res = await fetch(
    `http://${authHost()}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const body = (await res.json()) as { idToken?: string; error?: unknown };
  if (!body.idToken) throw new Error(`custom token sign-in failed: ${JSON.stringify(body.error)}`);
  return body.idToken;
}

/** The decoded claims of an ID token (the emulator's tokens are unsigned, so this just reads them). */
export const claimsOf = (token: string) =>
  JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()) as Record<string, unknown>;

/** An SMS sender that records what it was asked to send, and can be told to fail. */
export function fakeSender() {
  const sent: { to: string; text: string }[] = [];
  const s = {
    sent,
    fail: false,
    send: async (to: string, text: string) => {
      if (s.fail) throw new Error('gateway down');
      sent.push({ to, text });
      return { gatewayId: `ATXid_${sent.length}` };
    },
  };
  return s;
}

export function makeApp(sender = fakeSender()) {
  return { app: createApp({ fb, sender }), sender };
}

export const bearer = (token: string) => `Bearer ${token}`;

export async function centre(id: string, name = `Centre ${id}`) {
  await fb.fs.collection('healthCenters').doc(id).set({ name, district: 'Test', sector: 'Test', callNumber: '+250780009999' });
  return id;
}

export async function chw(uid: string, hc: string, phone: string, pin = '1357', extra: Partial<AccountInput> = {}) {
  return createAccount(
    fb,
    {
      role: 'chw',
      fullName: `CHW ${uid}`,
      phone,
      pin,
      chwRole: 'asm',
      village: 'Nyamata',
      healthCenterId: hc,
      language: 'rw',
      ...extra,
    } as AccountInput,
    uid,
  );
}

export async function supervisor(uid: string, hc: string, phone: string) {
  return createAccount(
    fb,
    {
      role: 'supervisor',
      fullName: `Supervisor ${uid}`,
      phone,
      email: `${uid}@example.test`,
      password: 'long-enough-password',
      healthCenterId: hc,
      language: 'en',
    },
    uid,
  );
}

export async function admin(uid = 'admin-1', phone = '+250780000099') {
  return createAdmin(fb, { fullName: 'Test Admin', phone, email: `${uid}@example.test`, password: 'admin-password-123' }, uid);
}

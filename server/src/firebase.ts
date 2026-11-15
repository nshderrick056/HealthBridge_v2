import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { env } from './env';

export type Fb = { fs: Firestore; auth: Auth };

/**
 * The Admin SDK for project healthbridge-rwanda. It bypasses the security rules, so it only runs on the
 * server. Credentials: FIREBASE_SERVICE_ACCOUNT (the key's JSON, for Vercel) or GOOGLE_APPLICATION_CREDENTIALS
 * (a path to the key file, kept outside the repo). Against the emulators (FIRESTORE_EMULATOR_HOST and
 * FIREBASE_AUTH_EMULATOR_HOST set) no key is needed.
 */
export function createFirebase(name = '[DEFAULT]'): Fb {
  const emulated = !!process.env.FIRESTORE_EMULATOR_HOST;
  const app =
    getApps().find((a) => a.name === name) ??
    initializeApp(
      {
        projectId: env.FIREBASE_PROJECT_ID,
        // The emulator accepts unsigned custom tokens; naming an account skips the cloud metadata lookup.
        ...(emulated && { serviceAccountId: `emulator@${env.FIREBASE_PROJECT_ID}.iam.gserviceaccount.com` }),
        ...(!emulated && {
          credential: env.FIREBASE_SERVICE_ACCOUNT
            ? cert(JSON.parse(env.FIREBASE_SERVICE_ACCOUNT))
            : applicationDefault(),
        }),
      },
      name,
    );
  const fs = getFirestore(app);
  return { fs, auth: getAuth(app) };
}

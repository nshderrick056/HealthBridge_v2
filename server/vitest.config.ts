import { defineConfig } from 'vitest/config';

// Tests run against the Firebase emulators under the offline-only project "demo-healthbridge":
// `npm test` starts them with `firebase emulators:exec`, which sets FIRESTORE_EMULATOR_HOST and
// FIREBASE_AUTH_EMULATOR_HOST. Nothing here reads .env, so a test can never reach the real project.
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    // One emulator database for every file, so files run one at a time and each clears it first.
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 30_000,
    env: {
      FIREBASE_PROJECT_ID: 'demo-healthbridge',
      JWT_SECRET: 'test-reset-secret-test-reset-secret',
      SMS_KEY_ENC_KEY: '0f'.repeat(32),
      SMS_WEBHOOK_SECRET: 'test-webhook-secret-1234',
    },
  },
});

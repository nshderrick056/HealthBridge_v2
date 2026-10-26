import { defineConfig } from 'vitest/config';

// The sync tests need a real Postgres: CI sets DATABASE_URL, local runs take it from .env.
try {
  process.loadEnvFile();
} catch {}

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    env: {
      JWT_SECRET: 'test-access-secret-test-access-secret',
      JWT_REFRESH_SECRET: 'test-refresh-secret-test-refresh-secret',
      SMS_KEY_ENC_KEY: '0f'.repeat(32),
      SMS_WEBHOOK_SECRET: 'test-webhook-secret-1234',
    },
  },
});

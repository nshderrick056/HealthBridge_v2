import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    env: {
      JWT_SECRET: 'test-access-secret-test-access-secret',
      JWT_REFRESH_SECRET: 'test-refresh-secret-test-refresh-secret',
    },
  },
});

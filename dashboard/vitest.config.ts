import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: { alias: { '@': fileURLToPath(new URL('./', import.meta.url)) } },
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    include: ['test/**/*.test.{ts,tsx}'],
    // jsdom start-up plus the first render can take several seconds on a cold, busy machine.
    testTimeout: 30_000,
    env: { API_URL: 'http://api.test' },
  },
});

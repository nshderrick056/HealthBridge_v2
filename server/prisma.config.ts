import { defineConfig } from 'prisma/config';

// Local dev reads .env; CI and Vercel set real env vars, so a missing file is fine.
try {
  process.loadEnvFile();
} catch {}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    // Direct (non-pooled) URL: migrations need it on Neon. Plain process.env (not env()) so
    // `prisma generate` works on installs where no database URL is set.
    url: process.env.DIRECT_URL as string,
  },
});

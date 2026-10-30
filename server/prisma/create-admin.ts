// Creates the first real admin (there is no sign-up). Run once per deployment:
//   ADMIN_EMAIL=... ADMIN_PHONE=+250... ADMIN_PASSWORD=... ADMIN_NAME="..." npm run create-admin
// The admin then creates health centres, supervisors and CHWs through POST /admin/*.
import { hash } from '@node-rs/argon2';
import { z } from 'zod';
import { createPrisma } from '../src/db';

try {
  process.loadEnvFile();
} catch {}

const input = z
  .object({
    ADMIN_EMAIL: z.email(),
    ADMIN_PHONE: z.string().regex(/^\+?\d{9,15}$/),
    ADMIN_PASSWORD: z.string().min(12, 'use at least 12 characters for the admin password'),
    ADMIN_NAME: z.string().trim().min(2).default('Administrator'),
  })
  .parse(process.env);

const db = createPrisma(process.env.DIRECT_URL ?? process.env.DATABASE_URL);
const existing = await db.users.findFirst({ where: { OR: [{ email: input.ADMIN_EMAIL }, { phone: input.ADMIN_PHONE }] } });
if (existing) {
  console.log('An account with that email or phone already exists; nothing changed.');
} else {
  await db.users.create({
    data: {
      role: 'admin',
      full_name: input.ADMIN_NAME,
      email: input.ADMIN_EMAIL,
      phone: input.ADMIN_PHONE,
      secret_hash: await hash(input.ADMIN_PASSWORD),
      language: 'en',
    },
  });
  console.log(`Admin ${input.ADMIN_EMAIL} created.`);
}
await db.$disconnect();

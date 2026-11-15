// Creates the first real admin (there is no sign-up). Run once per project:
//   ADMIN_EMAIL=... ADMIN_PHONE=+250... ADMIN_PASSWORD=... ADMIN_NAME="..." npm run create-admin
// The admin then creates health centres, supervisors and CHWs through POST /admin/*.
import { z } from 'zod';
import { createAdmin } from '../src/accounts';
import { createFirebase } from '../src/firebase';

const input = z
  .object({
    ADMIN_EMAIL: z.email(),
    ADMIN_PHONE: z.string().regex(/^\+\d{9,15}$/),
    ADMIN_PASSWORD: z.string().min(12, 'use at least 12 characters for the admin password'),
    ADMIN_NAME: z.string().trim().min(2).default('Administrator'),
  })
  .parse(process.env);

try {
  await createAdmin(createFirebase(), {
    fullName: input.ADMIN_NAME,
    phone: input.ADMIN_PHONE,
    email: input.ADMIN_EMAIL,
    password: input.ADMIN_PASSWORD,
  });
  console.log(`Admin ${input.ADMIN_EMAIL} created.`);
} catch (e) {
  if (/already-exists/.test((e as { code?: string }).code ?? '')) {
    console.log('An account with that email or phone already exists; nothing changed.');
  } else {
    throw e;
  }
}

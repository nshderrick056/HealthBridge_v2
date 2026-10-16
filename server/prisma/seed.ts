// Synthetic development data only (PRD §6). Credentials come from env so none are committed.
import { hash } from '@node-rs/argon2';
import { createPrisma } from '../src/db';

try {
  process.loadEnvFile();
} catch {}

const pin = process.env.SEED_PIN;
const password = process.env.SEED_PASSWORD;
if (!pin || !/^\d{4,6}$/.test(pin) || !password || password.length < 8) {
  throw new Error('Set SEED_PIN (4-6 digits) and SEED_PASSWORD (8+ chars) to seed users');
}

// PLACEHOLDER danger signs: codes and English labels to be confirmed from the Figma forms and by a
// clinician (PRD §7). Kinyarwanda labels must come from a native speaker, never machine translation.
const dangerSigns = [
  { code: 'HB', visit_type: 'maternal', label_en: 'Heavy bleeding' },
  { code: 'CV', visit_type: 'maternal', label_en: 'Convulsions' },
  { code: 'SH', visit_type: 'maternal', label_en: 'Severe headache or blurred vision' },
  { code: 'UD', visit_type: 'child', label_en: 'Unable to drink or breastfeed' },
  { code: 'VE', visit_type: 'child', label_en: 'Vomits everything' },
  { code: 'CC', visit_type: 'child', label_en: 'Convulsions' },
  { code: 'LT', visit_type: 'malaria', label_en: 'Lethargic or unconscious' },
  { code: 'HF', visit_type: 'malaria', label_en: 'Very high fever' },
  { code: 'MR', visit_type: 'nutrition', label_en: 'MUAC red' },
  { code: 'OE', visit_type: 'nutrition', label_en: 'Swelling of both feet' },
] as const;

const db = createPrisma(process.env.DIRECT_URL ?? process.env.DATABASE_URL);

const centre = await db.health_centers.upsert({
  where: { id: '11111111-1111-4111-8111-111111111111' },
  update: {},
  create: {
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Demo Health Centre',
    district: 'Demo District',
    sector: 'Demo Sector',
    call_number: '+250780000100',
  },
});

const pinHash = await hash(pin);
const passwordHash = await hash(password);

await db.users.upsert({
  where: { phone: '+250780000100' },
  update: {},
  create: {
    role: 'supervisor',
    full_name: 'Demo Supervisor',
    phone: '+250780000100',
    email: 'supervisor@example.test',
    secret_hash: passwordHash,
    health_center_id: centre.id,
    language: 'en',
  },
});

for (const [i, village] of ['Village A', 'Village B', 'Village C'].entries()) {
  const phone = `+25078000010${i + 1}`;
  await db.users.upsert({
    where: { phone },
    update: {},
    create: {
      role: 'chw',
      chw_role: i === 0 ? 'asm' : 'binome',
      full_name: `Demo CHW ${i + 1}`,
      phone,
      secret_hash: pinHash,
      health_center_id: centre.id,
      village,
    },
  });
}

for (const s of dangerSigns) {
  await db.danger_signs.upsert({
    where: { code: s.code },
    update: {},
    create: { ...s, label_rw: `[RW pending] ${s.label_en}` },
  });
}

console.log('Seeded: 1 health centre, 1 supervisor, 3 CHWs, %d placeholder danger signs', dangerSigns.length);
await db.$disconnect();

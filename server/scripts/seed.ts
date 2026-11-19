// Synthetic demo data only (PRD §6): one health centre, an admin, a supervisor, three CHWs and the
// placeholder danger signs. Credentials come from env so none are committed. Safe to run again: it skips
// what exists. Runs against the emulators when FIRESTORE_EMULATOR_HOST is set, else the real project.
//   SEED_PIN=4-6 digits  SEED_PASSWORD=8+ chars  npm run seed
// The demo CHW phones are not real numbers: sign them in with phone + PIN, not with an SMS code.
import { createAccount, createAdmin } from '../src/accounts';
import { createFirebase } from '../src/firebase';

const pin = process.env.SEED_PIN;
const password = process.env.SEED_PASSWORD;
if (!pin || !/^\d{4,6}$/.test(pin) || !password || password.length < 8) {
  throw new Error('Set SEED_PIN (4-6 digits) and SEED_PASSWORD (8+ chars) to seed users');
}

// PLACEHOLDER danger signs: codes and English labels to be confirmed by a clinician (PRD §7).
// Kinyarwanda labels must come from a native speaker, never machine translation.
const dangerSigns = [
  { code: 'HB', visitType: 'maternal', labelEn: 'Heavy bleeding' },
  { code: 'CV', visitType: 'maternal', labelEn: 'Convulsions' },
  { code: 'SH', visitType: 'maternal', labelEn: 'Severe headache or blurred vision' },
  { code: 'UD', visitType: 'child', labelEn: 'Unable to drink or breastfeed' },
  { code: 'VE', visitType: 'child', labelEn: 'Vomits everything' },
  { code: 'CC', visitType: 'child', labelEn: 'Convulsions' },
  { code: 'LT', visitType: 'malaria', labelEn: 'Lethargic or unconscious' },
  { code: 'HF', visitType: 'malaria', labelEn: 'Very high fever' },
  { code: 'MR', visitType: 'nutrition', labelEn: 'MUAC red' },
  { code: 'OE', visitType: 'nutrition', labelEn: 'Swelling of both feet' },
];

const fb = createFirebase();
const HC = 'demo-health-centre';

await fb.fs.collection('healthCenters').doc(HC).set(
  { name: 'Demo Health Centre', district: 'Demo District', sector: 'Demo Sector', callNumber: '+250780000100' },
  { merge: true },
);
for (const s of dangerSigns) {
  await fb.fs
    .collection('dangerSigns')
    .doc(s.code)
    .set({ visitType: s.visitType, labelEn: s.labelEn, labelRw: `[RW pending] ${s.labelEn}` });
}

/** Runs [make] unless the account already exists (stable IDs make the seed repeatable). */
async function once(uid: string, make: () => Promise<string>) {
  try {
    await fb.auth.getUser(uid);
    console.log(`  exists: ${uid}`);
  } catch {
    await make();
    console.log(`  created: ${uid}`);
  }
}

await once('demo-admin', () =>
  createAdmin(
    fb,
    { fullName: 'Demo Admin', phone: '+250780000099', email: 'admin@example.test', password },
    'demo-admin',
  ),
);
await once('demo-supervisor', () =>
  createAccount(
    fb,
    {
      role: 'supervisor',
      fullName: 'Demo Supervisor',
      phone: '+250780000100',
      email: 'supervisor@example.test',
      password,
      healthCenterId: HC,
      language: 'en',
    },
    'demo-supervisor',
  ),
);
for (const [i, village] of ['Village A', 'Village B', 'Village C'].entries()) {
  const uid = `demo-chw-${i + 1}`;
  await once(uid, () =>
    createAccount(
      fb,
      {
        role: 'chw',
        fullName: `Demo CHW ${i + 1}`,
        phone: `+25078000010${i + 1}`,
        pin,
        chwRole: i === 0 ? 'asm' : 'binome',
        village,
        healthCenterId: HC,
        language: 'rw',
      },
      uid,
    ),
  );
}
console.log('Seeded: 1 health centre, 1 admin, 1 supervisor, 3 CHWs, %d placeholder danger signs', dangerSigns.length);

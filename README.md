# HealthBridge Rwanda

Offline-first Android app for community health workers (CHWs), their supervisors and an admin, on Firebase
(Cloud Firestore + Firebase Auth), with a small Express server for what an app must not do and an encrypted
SMS fallback for urgent alerts. The specs are in [documents/](documents/). What the whole project does and how it
fits together is in [PRODUCT.md](PRODUCT.md) (with the split of the code among five people); the scripts for the
demo video are in [docs/VIDEO_SCRIPTS.md](docs/VIDEO_SCRIPTS.md).

The look is one design system: Outfit font, brand green `#19695A` with lime `#D4FF89`, 24 px cards, 56 px pill
buttons and a floating tab bar (`lib/core/theme/app_theme.dart`, `lib/core/widgets/`). The web dashboard uses the
same tokens.

## Screenshots

<!-- TODO: add screenshots here (docs/screenshots/*.png): sign-in, CHW home with the stat cards, patient
profile, urgent alert, supervisor inbox and case, CHW and patient history, admin Members, web dashboard. -->

## Layout

| Path | What |
| --- | --- |
| `lib/` | Flutter app (Android only), in layers: `presentation/` (screens from the Figma file `healthbridge-v2`, each with a Riverpod controller beside it; no `setState`), `domain/` (entities, repository interfaces, use cases), `data/` (encrypted drift database and the repositories implementing the domain interfaces). Around them: `core/` (Firebase sign-in, API client, settings in SharedPreferences, SMS codec, theme, shared widgets), `sync/` (upload to Firestore and background sync) and `urgent/` (urgent-alert pathway). |
| `firestore.rules`, `firestore.indexes.json` | Firestore security rules and indexes (deployed to project `healthbridge-rwanda`). |
| `docs/ERD.md` | Entity-relationship diagram of the Firestore collections. |
| `server/` | Express + TypeScript on the Firebase Admin SDK: PIN sign-in, accounts and resets, device keys, the SMS gateway, alert status changes. Tested with Vitest against the Firebase emulators. |
| `dashboard/` | Web dashboard (Next.js), signing in with Firebase: supervisors get alerts, CHWs and patients with their visit history; admins get Resets, Members (CHW and Supervisor tabs, deactivate and delete) and Centres. |
| `android/` | Flavours `store` (no SMS permission, opens the SMS composer) and `managed` (sends SMS itself through the Kotlin channel in `app/src/managed/kotlin/`). `app/google-services.json` is the app's public Firebase config. |
| `shared/sms-vectors.json` | Test vectors both SMS codecs (TypeScript and Dart) must pass. |

## How it works

- **Roles and sign-in (Firebase Auth).** Only an admin creates accounts; self sign-up and self-delete are off in
  Firebase. Each account carries its role (`chw`, `supervisor`, `admin`) and health centre as custom claims.
  Three ways in: **phone + PIN** (the server checks the PIN and returns a Firebase custom token), **phone + SMS
  code** (Firebase texts it), **email + password**. After sign-in the app opens the screens for the role.
- **New accounts.** The admin enters the person's details only; the server makes a random temporary PIN (CHW)
  and/or password (with an email) and texts them to the person. At first sign-in the app asks them to choose
  their own before anything else, and the dashboard refuses the temporary password. The SMS gateway carries them;
  the admin never sees them.
- **Forgot PIN or password.** The user asks in the app; the admin approves it on the Resets tab; the server texts
  a one-time code (hashed, 30 minutes, 5 tries); the user enters it and sets a new PIN or password, and is signed
  out everywhere else.
- **CHW data, offline first.** Patients and visits are saved in an encrypted SQLite database (SQLCipher) with an
  upload queue, so nothing is lost offline. When online, sync writes each change to its Firestore document as the
  signed-in CHW, under the security rules, and pulls the CHW's patients, alert confirmations, danger signs and the
  health centre's call number. Firestore's own (unencrypted) offline cache is off. One CHW's records per phone:
  another CHW can only sign in once everything has uploaded.
- **Urgent alerts.** Online, the visit and its alert go to Firestore together within 10 s. Otherwise the app sends
  an encrypted SMS (AES-GCM, the device's own key) to the Africa's Talking number; the server decrypts it, stores a
  partial case and replies `HB OK <code> <tag>` (HMAC-signed, so only the server can confirm). When the phone is
  back online it uploads the full visit and the server merges the two into one case.
- **Supervisors** see their health centre's alerts (inbox, case detail, status changes with a note), their CHWs
  and patients in the app or on the web dashboard. Tapping a CHW shows every visit that CHW recorded; tapping a
  patient shows their profile and visit history; a visit opens its full detail. Status changes go through the
  server, which checks the allowed moves, records who made them and texts the CHW on Escalate and Follow-up.
  Everything is scoped to the supervisor's own centre on the server.
- **CHW home** shows stat cards (visited today, due for a visit, urgent today), today's due patients and visits,
  and a pill for the connection and what is still waiting to upload.
- **Admins** (app and web) approve resets, create accounts, and manage Members in two tabs (CHWs, Supervisors):
  open a member to see their details, deactivate them (Firestore `active:false`, Auth user disabled, tokens
  revoked, so they are out at once) or delete them (account, credentials and devices go; patients and visits are
  kept). A health centre's name opens its details. Admin accounts are never touched from these screens.
- **Security rules** (`firestore.rules`): a CHW reads and writes only their own patients and visits (field by
  field validation; a visit is urgent exactly when it has danger signs), a supervisor reads only their centre's,
  nothing can be deleted (archive instead), and PIN hashes, device keys, reset requests and logs are server-only.

## Status

| Part | State |
| --- | --- |
| Firebase project, rules, indexes, ERD | done, deployed |
| Sign-in (PIN, SMS code, email), forgot flow, role screens | done, tested on a phone (15 Nov 2026) |
| CHW app: patients (create, edit, archive), visits, sync to Firestore, settings | done, tested on a phone |
| Urgent alert by internet; supervisor inbox, escalate with note; admin new account and reset approval | done, tested on a phone |
| Offline SMS alert and merge on Firebase | code and server tests done; last phone run was on the Postgres version (1 Nov) |
| Redesign (Outfit, green and lime), history screens, admin Members and centre details, CHW stat cards | done, installed on a phone; the newest screens are covered by tests, not yet by a full phone run |
| Web dashboard on Firebase sign-in (supervisor and admin) | done, tested by unit tests only |
| Tests | 129 Flutter (unit, widget, layout at 4 sizes: 320x568, 430x932, landscape, landscape with extra-large text), 48 server (Firebase emulators), 35 dashboard |

## Phone tests

**15 November 2026, Firebase build** (managed build on a Samsung, API behind a Cloudflare tunnel, Africa's
Talking sandbox): all three sign-in methods; a patient and visit appearing in Firestore under the CHW; forgot PIN
from request to a working new PIN (code read in the sandbox simulator); an urgent alert reaching the supervisor's
inbox, escalated with a note and recorded in the history; the admin creating an account. Found and fixed on the
way: custom tokens must be signed with the key file (the IAM signing API is off in a new project), the SMS region
policy had to allow Rwanda, and records left by an older install uploaded under the new account (now one CHW per
phone).

**1 November 2026, Postgres build**: urgent visit offline sent the sealed SMS by itself; the server decrypted it
and created the case; back online, the full visit replaced the partial one; Escalate texted the CHW.

## Still to do

- **On a phone:** the offline SMS alert and merge on the Firebase build; 20 visits offline through an app kill and a
  reboot; background sync with the app closed; the managed build confirming from a real `HB OK` reply.
- **SMS:** the Africa's Talking sandbox only reaches its simulator. Real phones (urgent acks, reset codes, CHW
  notices) need a live Africa's Talking number. Firebase also allows only 10 sign-in SMS a day until billing is
  added (the test number does not count).
- **Release:** host the API (Vercel) and dashboard, create the signing keystore and GitHub secrets (see Release).
- **Clinical content:** the danger signs and validation ranges (`lib/data/forms/`) are placeholders until a
  clinician confirms them. **Kinyarwanda:** app text is English; it needs translation by a native speaker.
- **Before the Play upload:** workmanager adds foreground-service and boot permissions; Play may ask why.

## Run it

Needs Flutter (stable), Node 20+, Java 21 (for the Firebase emulators) and the Firebase CLI (`npm i -g firebase-tools`).

```bash
# server (needs the service account key: Firebase console > Project settings > Service accounts)
cd server
cp .env.example .env        # GOOGLE_APPLICATION_CREDENTIALS = path to the key, kept OUTSIDE the repo
npm ci
npm test                    # starts the Firebase emulators (offline project demo-healthbridge)
npm run seed                # demo data into the real project (SEED_PIN, SEED_PASSWORD from .env)
npm run dev

# app (API_URL: where the phone reaches the server, e.g. a Cloudflare tunnel)
flutter pub get
flutter test
flutter run --flavor managed --dart-define=API_URL=https://<host> --dart-define=SMS_GATEWAY_NUMBER=+2507XXXXXXXX

# web dashboard (needs the server running)
cd dashboard
cp .env.example .env.local  # API_URL and FIREBASE_WEB_API_KEY
npm ci && npm test
npm run dev                 # http://localhost:3001, sign in as supervisor@example.test with SEED_PASSWORD
```

Demo accounts from `npm run seed`: CHWs `+250780000101` to `103` with `SEED_PIN` (sign in with the PIN: these
numbers are not real phones); supervisor `supervisor@example.test` and admin `admin@example.test` with
`SEED_PASSWORD`. In the app, the admin creates further accounts (New account tab), adds health centres (Centres tab) and approves resets.

The first real admin of a project: `ADMIN_EMAIL=... ADMIN_PHONE=+250... ADMIN_PASSWORD='12+ chars' npm run create-admin`.

After changing the rules: `firebase deploy --only firestore`. After changing a drift table: `dart run build_runner build`.

## SMS gateway (Africa's Talking)

Point the callbacks at `https://<host>/webhooks/sms?secret=<SMS_WEBHOOK_SECRET>` (inbound) and
`.../webhooks/sms/delivery?secret=...` (delivery reports), and set `AT_USERNAME` (`sandbox` for the simulator),
`AT_API_KEY` and `AT_SENDER` in `server/.env`. The app sends urgent SMS to `SMS_GATEWAY_NUMBER` (set at build
time). In the sandbox, open the simulator on a number before a message to it is sent, or it may not show.

## Release

1. **API:** a Vercel project with root `server/`. Env vars: `FIREBASE_SERVICE_ACCOUNT` (the key's JSON),
   `JWT_SECRET`, `SMS_KEY_ENC_KEY`, `SMS_WEBHOOK_SECRET`, `AT_*`, `CORS_ORIGINS` (the dashboard URL).
2. **Dashboard:** a Vercel project with root `dashboard/`. Env vars `API_URL`, `FIREBASE_WEB_API_KEY`.
3. **Firestore:** `firebase deploy --only firestore`; then `npm run create-admin` for the first admin.
4. **Signing key** (once; a lost key means a new app listing):
   `keytool -genkey -v -keystore healthbridge-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias healthbridge`.
   Add its SHA-1 and SHA-256 to both Android apps in the Firebase console, or phone sign-in fails in release builds.
5. **GitHub secrets:** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
   `ANDROID_STORE_PASSWORD`; variables `API_URL`, `SMS_GATEWAY_NUMBER`. Then `git tag v1.0.0 && git push origin v1.0.0`.

## Secrets

This repo is public. Only `.env.example` files are committed; the service account key lives outside the repo
(locally) or in `FIREBASE_SERVICE_ACCOUNT` (Vercel). `google-services.json` and the Firebase web API key are public
by design: they name the project; access is controlled by Firebase Auth and the security rules. Seed data is
synthetic.

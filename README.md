# HealthBridge Rwanda

Offline-first Android app for community health workers (CHWs), with an Express API, a Next.js supervisor
dashboard and an encrypted SMS fallback for urgent alerts. The specs are in [documents/](documents/); the
build plan is `documents/HealthBridge Rwanda — Build Plan.md`.

## Layout

| Path | What |
| --- | --- |
| `lib/` | Flutter app (Android only), in layers: `presentation/` (screens from the Figma file `healthbridge-v2`, each with a Riverpod controller beside it; no `setState`), `domain/` (entities, repository interfaces, use cases), `data/` (encrypted drift database and the repositories implementing the domain interfaces). Around them: `core/` (auth, settings in SharedPreferences, SMS codec, theme tokens, shared widgets), `sync/` (outbox upload and background sync) and `urgent/` (urgent-alert pathway). Patient and Visit are drift's generated row classes, used as the domain entities rather than duplicated. |
| `docs/ERD.md` | Entity-relationship diagram of the database, drawn from the Prisma schema. |
| `android/` | Flavours `store` (no SMS permission, opens the SMS composer) and `managed` (sends SMS directly through the Kotlin channel in `app/src/managed/kotlin/`, no SMS plugin). |
| `server/` | Express + TypeScript + Prisma API, tested with Vitest and Supertest. |
| `shared/sms-vectors.json` | Test vectors that both the TypeScript and Dart SMS codecs must pass. |
| `dashboard/` | Supervisor dashboard (Next.js + Tailwind, tested with Vitest). Talks to the API through its own route handlers, which keep the tokens in httpOnly cookies. |
| `documents/` | PRD, TRD, Backend Schema, App Flow, Design Brief, Implementation Plan, Build Plan. |

## Status

| Slice | | State |
| --- | --- | --- |
| 0 | Bootstrap, flavours, CI | done |
| 1 | Backend foundations: schema, seed, login, refresh | done |
| 2 | SMS codec (TS and Dart) | done |
| 3 | SMS round trip: `POST /devices/register`, `POST /webhooks/sms`, `/webhooks/sms/delivery`, ack SMS | done; run against the Africa's Talking sandbox (see Phone test below) |
| 4 | Flutter data layer: encrypted drift DB, repositories, outbox, providers | done (see [lib/data/README.md](lib/data/README.md)) |
| UI | CHW screens from Figma: login, home, patients, patient profile, record/review visit, urgent, saved, sync status (plus register-patient, alerts and profile tabs, which Figma lacks) | done; the two supervisor frames go to the web dashboard (slice 7) |
| 5 | Sync engine: `/sync/push` (idempotent, merges SMS partial cases), `/sync/pull`, app outbox drain with back-off (`lib/sync/`) | done: while open (start, resume, connectivity, every minute) and on Android with the app closed (workmanager every 30 min once online, `lib/sync/background_sync.dart`); the SMS case merging into the full visit on reconnect is confirmed on a phone, the 20-visit reboot and closed-app runs are not |
| 6 | Urgent pathway: `POST /alerts` (internet, 10 s), else the sealed SMS through `UrgentSender` (composer in `store`, direct send + ack receiver in `managed`); unconfirmed after 10 min with Resend and Call (`lib/urgent/`) | done; the managed build's direct send is confirmed on a real SIM |
| 7 | Supervisor dashboard: `GET /alerts`, `GET`/`PATCH /alerts/:id`, `GET /chws` (scoped to the supervisor's health centre); `dashboard/` with login, 10 s alert inbox, case detail with status actions, CHW list | done (not yet deployed); Escalate and Follow-up also text the CHW the case code |
| 8 | Release: Vercel entry (`server/api/`), signed builds and migrations on a `v*` tag (`.github/workflows/release.yml`), admin endpoints for real accounts | code done; needs your Vercel/Neon accounts, keystore and GitHub secrets (see Release below) |

## Phone test (1 November 2026)

Managed build on a Samsung (Android, real SIM), API on a laptop behind a Cloudflare quick tunnel, Africa's
Talking sandbox, supervisor dashboard on localhost.

| Step | Result |
| --- | --- |
| Urgent visit with Wi-Fi and mobile data off | The internet attempt failed and the app sent the sealed `HB1` SMS by itself to a second phone. The first send failed at the radio ("Failed to send", cause unknown); Resend went through. |
| SMS into the server | Copied from the second phone into the sandbox simulator (the sandbox cannot receive real SMS). The server decrypted it, created the case (channel SMS, patient "(awaiting sync)") and the sandbox accepted the `HB OK <code>` reply. |
| Dashboard | The case appeared in the inbox. |
| Data back on | The phone synced within a minute; the full visit replaced the partial one (one visit, real patient name, no stub patient left). |
| Escalate | The "case … has been escalated" SMS was sent to the CHW's number. |

Not covered: the phone reading the `HB OK` reply by itself (the reply went to the simulator, not the phone), a
real gateway number, 20 visits through a reboot, and background sync with the app closed.

## Still to do

- **On a phone:** 20 visits recorded offline, app killed and phone rebooted, each syncing exactly once;
  background sync firing with the app closed; the managed build confirming from a real `HB OK` reply.
- **SMS gateway:** the sandbox only talks to its simulator, so a hands-free test needs a live Africa's Talking
  number (or a phone acting as a gateway).
- **Release:** create the accounts, keystore and secrets in the Release section below, then push a `v*` tag.
  After that, clean installs of both builds against the deployed API, checking an alert reaches the dashboard
  within 10 s.
- **Clinical content:** the danger-sign list and the validation ranges (`lib/data/forms/`) are placeholders
  until a clinician confirms them.
- **Kinyarwanda (FR-17):** app text is English and hard-coded in the screens; it needs translation files and a
  native speaker. Danger-sign labels in the database are marked `[RW pending]`.
- **Acks:** the server's reply is `HB OK <code> <tag>`, the tag being HMAC-SHA256 with the device's SMS key, and
  the managed build ignores a reply whose tag does not match. Replay of a genuine reply is harmless (it only
  confirms the same alert). Not yet checked on a phone with a live gateway.
- **Local only:** `web/` (browser preview) and `windows/` are not committed.
- **Before the Play upload:** workmanager adds foreground-service, wake-lock, boot and notification permissions
  to both builds; Play may ask for a foreground-service justification.

## Run it

Needs Flutter (stable), Node 20+ and PostgreSQL 16 or later.

```bash
# server
cd server
cp .env.example .env        # fill in the secrets, see the comments in the file
npm ci
npm run db:migrate && npm run db:seed
npm test
npm run dev

# app
flutter pub get
flutter test
flutter run --flavor store --dart-define=SMS_GATEWAY_NUMBER=+2507XXXXXXXX   # or --flavor managed
flutter run -d chrome --web-port 8080   # browser preview: keep the port fixed, browser data is stored per port

# supervisor dashboard (needs the server running)
cd dashboard
cp .env.example .env.local  # API_URL=http://localhost:3000
npm ci
npm test
npm run dev                 # http://localhost:3001, sign in as supervisor@example.test with SEED_PASSWORD
```

Demo logins from `npm run db:seed`: CHWs `+250780000101`, `+250780000102`, `+250780000103` with `SEED_PIN` (in
the app); the supervisor `supervisor@example.test` with `SEED_PASSWORD` (in the dashboard); the admin
`admin@example.test` with `SEED_PASSWORD` (API only, below).

Real accounts (there is no sign-up): an admin creates health centres and people over the API.

```bash
# first admin of a deployment (reads DATABASE_URL/DIRECT_URL from server/.env)
ADMIN_EMAIL=you@example.org ADMIN_PHONE=+2507XXXXXXXX ADMIN_PASSWORD='at-least-12-chars' npm run create-admin
# then, with the admin's access token from POST /auth/login:
#   POST /admin/health-centers {name, district, sector, callNumber?}
#   POST /admin/users {role:"chw", fullName, phone, pin, chwRole:"asm"|"binome", village, healthCenterId}
#   POST /admin/users {role:"supervisor", fullName, phone, email, password, healthCenterId}
```

Build both APKs and check that only the managed one asks for SMS permissions (CI does the same):

```bash
flutter build apk --debug --flavor store
flutter build apk --debug --flavor managed
"$ANDROID_HOME"/build-tools/<version>/aapt dump permissions build/app/outputs/flutter-apk/app-store-debug.apk
```

`android/gradle.properties` turns off Kotlin incremental builds: some plugins' caches fail when the pub cache
(C:) and the project are on different drives.

After changing a drift table, regenerate `lib/data/db.g.dart` (it is committed):

```bash
dart run build_runner build
```

## SMS gateway (Africa's Talking)

Point the gateway callbacks at `https://<host>/webhooks/sms?secret=<SMS_WEBHOOK_SECRET>` (inbound) and
`https://<host>/webhooks/sms/delivery?secret=<SMS_WEBHOOK_SECRET>` (delivery reports). Set `AT_USERNAME`
(`sandbox` for the simulator) and `AT_API_KEY` in `server/.env`. Without them alerts are still stored but
no acknowledgement SMS is sent.

The app sends urgent SMS to the gateway's number, set at build time with
`--dart-define=SMS_GATEWAY_NUMBER=<shortcode or +250... number>` (add `--dart-define=API_URL=https://<host>`
for a real server). Without it the `managed` build cannot send (the alert shows as unconfirmed with Resend and
Call) and the `store` build opens the SMS app with no recipient. The Call button dials the health centre's
`call_number`, which the phone receives on each sync.

## Release

1. **Database:** create a Neon Postgres project (Vercel Marketplace). Keep its pooled URL and its direct URL.
2. **API on Vercel:** new project, root directory `server/`. Env vars: `DATABASE_URL` (pooled), `DIRECT_URL`
   (direct), `JWT_SECRET`, `JWT_REFRESH_SECRET`, `SMS_KEY_ENC_KEY`, `SMS_WEBHOOK_SECRET`, `AT_USERNAME`,
   `AT_API_KEY`, `AT_SENDER`, `CORS_ORIGINS` (the dashboard URL). `server/api/index.ts` serves every path.
3. **Dashboard on Vercel:** new project, root directory `dashboard/`, env var `API_URL` (the API URL).
4. **First data:** from `server/` with the Neon direct URL in `.env`, run `npm run db:migrate`, then
   `npm run create-admin` (real) or `npm run db:seed` (demo data only, never alongside real patients).
5. **Signing key** (once; keep the file and passwords safe, a lost key means a new app listing):
   ```bash
   keytool -genkey -v -keystore healthbridge-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias healthbridge
   ```
6. **GitHub (Settings → Secrets and variables → Actions):** secrets `PROD_DIRECT_URL`,
   `ANDROID_KEYSTORE_BASE64` (`base64 -w0 healthbridge-release.jks`), `ANDROID_KEY_ALIAS` (`healthbridge`),
   `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`; variables `API_URL`, `SMS_GATEWAY_NUMBER`.
7. **Ship:** `git tag v1.0.0 && git push origin v1.0.0`. The Release workflow migrates the database, builds the
   signed store `.aab` and managed `.apk`, checks SMS permissions, and attaches both to a GitHub release.

## Secrets

This repo is public. Only `.env.example` files are committed; real values live in local `.env` files,
Vercel and GitHub Actions secrets. Seed data is synthetic.
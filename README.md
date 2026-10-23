# HealthBridge Rwanda

Offline-first Android app for community health workers (CHWs), with an Express API, a Next.js supervisor
dashboard and an encrypted SMS fallback for urgent alerts. The specs are in [documents/](documents/); the
build plan is `documents/HealthBridge Rwanda — Build Plan.md`.

## Layout

| Path | What |
| --- | --- |
| `lib/` | Flutter app (Android only). `core/sms/` is the SMS codec, `data/` the offline database and repositories, `sync/` the outbox sync and `urgent/` the urgent-alert pathway. The CHW screens are in `features/` (from the Figma file `healthbridge-v2`), with theme tokens in `core/theme/` and shared widgets in `core/widgets/`. |
| `android/` | Flavours `store` (no SMS permission, opens the SMS composer) and `managed` (sends SMS directly through the Kotlin channel in `app/src/managed/kotlin/`, no SMS plugin). |
| `server/` | Express + TypeScript + Prisma API, tested with Vitest and Supertest. |
| `shared/sms-vectors.json` | Test vectors that both the TypeScript and Dart SMS codecs must pass. |
| `dashboard/` | Supervisor dashboard (Next.js). Not started. |
| `documents/` | PRD, TRD, Backend Schema, App Flow, Design Brief, Implementation Plan, Build Plan. |

## Status

| Slice | | State |
| --- | --- | --- |
| 0 | Bootstrap, flavours, CI | done |
| 1 | Backend foundations: schema, seed, login, refresh | done |
| 2 | SMS codec (TS and Dart) | done |
| 3 | SMS round trip: `POST /devices/register`, `POST /webhooks/sms`, `/webhooks/sms/delivery`, ack SMS | done (tested against fakes; not yet run against the Africa's Talking sandbox) |
| 4 | Flutter data layer: encrypted drift DB, repositories, outbox, providers | done (see [lib/data/README.md](lib/data/README.md)) |
| UI | CHW screens from Figma: login, home, patients, patient profile, record/review visit, urgent, saved, sync status (plus register-patient, alerts and profile tabs, which Figma lacks) | done; the two supervisor frames go to the web dashboard (slice 7) |
| 5 | Sync engine: `/sync/push` (idempotent, merges SMS partial cases), `/sync/pull`, app outbox drain with back-off (`lib/sync/`) | done while the app is open; syncing with the app closed (workmanager) is still to do |
| 6 | Urgent pathway: `POST /alerts` (internet, 10 s), else the sealed SMS through `UrgentSender` (composer in `store`, direct send + ack receiver in `managed`); unconfirmed after 10 min with Resend and Call (`lib/urgent/`) | done; the real-SIM run with the managed build is still to do |
| 7 | Supervisor dashboard | |
| 8 | Release and Vercel deploy | |

## Run it

Needs Flutter (stable), Node 20+ and PostgreSQL 16.

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
```

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

## Secrets

This repo is public. Only `.env.example` files are committed; real values live in local `.env` files,
Vercel and GitHub Actions secrets. Seed data is synthetic.
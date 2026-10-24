# HealthBridge Rwanda

Offline-first Android app for community health workers (CHWs), with an Express API, a Next.js supervisor
dashboard and an encrypted SMS fallback for urgent alerts. The specs are in [documents/](documents/); the
build plan is `documents/HealthBridge Rwanda — Build Plan.md`.

## Layout

| Path | What |
| --- | --- |
| `lib/` | Flutter app (Android only). `core/sms/` is the SMS codec, `data/` the offline database and repositories. The CHW screens are in `features/` (from the Figma file `healthbridge-v2`), with theme tokens in `core/theme/` and shared widgets in `core/widgets/`. |
| `android/` | Flavours `store` (no SMS permission, opens the SMS composer) and `managed` (sends SMS directly). |
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
| 3 | SMS round trip: `POST /devices/register`, `POST /webhooks/sms`, `/webhooks/sms/delivery`, ack SMS | done (tested against fakes; not yet run against the Africa's Talking sandbox) |
| 4 | Flutter data layer: encrypted drift DB, repositories, outbox, providers | done (see [lib/data/README.md](lib/data/README.md)) |
| UI | CHW screens from Figma: login, home, patients, patient profile, record/review visit, urgent, saved, sync status (plus register-patient, alerts and profile tabs, which Figma lacks) | done; the two supervisor frames go to the web dashboard (slice 7) |
| 5 | Sync engine: `/sync/push` (idempotent, merges SMS partial cases), `/sync/pull`, app outbox drain with back-off (`lib/sync/`) | done while the app is open; syncing with the app closed (workmanager) is still to do |
| 6 | Urgent pathway (`POST /alerts`, `UrgentSender`) | |
| 7 | Supervisor dashboard: `GET /alerts`, `GET`/`PATCH /alerts/:id`, `GET /chws` (scoped to the supervisor's health centre); `dashboard/` with login, 10 s alert inbox, case detail with status actions, CHW list | done (not yet deployed; Escalate and Follow-up do not SMS the CHW yet; the CHW sees them on the next sync) |
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
flutter run --flavor store   # or --flavor managed
flutter run -d chrome --web-port 8080   # browser preview: keep the port fixed, browser data is stored per port

# supervisor dashboard (needs the server running)
cd dashboard
cp .env.example .env.local  # API_URL=http://localhost:3000
npm ci
npm test
npm run dev                 # http://localhost:3001, sign in as supervisor@example.test with SEED_PASSWORD
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

## Secrets

This repo is public. Only `.env.example` files are committed; real values live in local `.env` files,
Vercel and GitHub Actions secrets. Seed data is synthetic.
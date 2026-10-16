# HealthBridge Rwanda: implementation plan (everything except the CHW app screens)

## Context
6 spec docs sit in `HealthBridge/documents/` (PRD, TRD, Backend Schema, App Flow, Design Brief, Implementation Plan). The CHW screens are designed in Figma and another member pushes them later. We build everything else in a **new, empty, public repo**, `https://github.com/nshderrick056/HealthBridge_v2.git`, cloned to `D:\personal projects\machine learning\flutter practices\HealthBridge_v2`.

**In scope:** Express API, Postgres schema, the SMS pipeline (TS and Dart), the Flutter data, sync and urgent layer under the screens, the store/managed flavours, the Next.js supervisor dashboard (confirmed ours), CI, and deploy on Vercel.
**Out of scope:** CHW screens, widgets, ARB strings.

Driver skill: **`/ecc:orch-build-mvp`**, run per slice with `--eval-mode code-only`. It gates on the slice plan and again before each commit. Per-slice helpers: `ecc:security-review` (slices 1–3 and 6), `ecc:healthcare-phi-compliance` (slices 1 and 4), `ecc:dart-flutter-patterns` (slices 4–6).

## Repo layout
```
HealthBridge_v2/
  lib/            Flutter (Android only). Ours: core/ data/ urgent/ sync/. Theirs later: features/ (screens)
  android/        flavours store + managed; android/app/src/managed/ holds SMS permissions + Kotlin channel
  integration_test/
  server/         Express + TypeScript + Prisma + Jest   → Vercel project #1 (root dir server/)
  dashboard/      Next.js + Tailwind + Vitest            → Vercel project #2 (root dir dashboard/)
  shared/sms-vectors.json                                  one test-vector file both codecs must pass
  documents/      the 6 spec docs + this plan
  .github/workflows/ci.yml
```
The repo is **public**, so nothing secret is ever committed. Only `.env.example` files go in, and all real values live in Vercel and GitHub Actions secrets.

## Hosting: Vercel (what changes from the TRD)
- **Dashboard** on Vercel: native fit.
- **API** on Vercel: the Express app is exported as a single Vercel function (`server/api/index.ts` → `app`). Nothing in the design needs a long-running server: the ack SMS is sent inside the webhook request, and the 10-minute "not confirmed" timer runs on the phone.
- **Postgres:** Neon through the Vercel Marketplace for production. Prisma uses the pooled URL at runtime and `directUrl` for migrations. Local dev uses PostgreSQL 16 installed on your machine.
- **argon2id** comes from `@node-rs/argon2`, whose prebuilt binaries work in serverless.
- Risk: a cold start could make the app's 5 s `HEAD /health` reachability check fail. Mitigation: `/health` touches no DB, and the app retries once before declaring itself offline.

## Slices

### 0. Bootstrap (one commit, pushed to `main`)
- Clone the empty repo. Run `flutter create --platforms android --org rw.healthbridge --project-name health_bridge .`, then set `applicationId "rw.healthbridge.app"` in `android/app/build.gradle.kts` and add the `store` and `managed` flavours (`applicationIdSuffix ".managed"`), plus the `managed` source set.
- Copy `documents/` across, with this plan saved as `documents/HealthBridge Rwanda — Build Plan.md`.
- `.gitignore` (Flutter, Node, `.env*` except `.env.example`), `analysis_options.yaml` excluding `server/**` and `dashboard/**`.
- `ci.yml` jobs:
  - **flutter**: analyze, test, then `flutter build apk --debug --flavor store` and `--flavor managed`. The job fails if the merged store manifest contains `SEND_SMS` (checked with grep on `build/app/intermediates/merged_manifests/storeDebug/**/AndroidManifest.xml`).
  - **server**: Postgres service container, `prisma migrate deploy`, jest.
  - **dashboard**: vitest, `next build`.
- After this, each slice goes on its own branch and PR, matching the team rule that another member reviews every PR.

### 1. Backend foundations (`server/`)
- `prisma/schema.prisma` is a 1:1 port of Backend Schema §1: 11 tables, the enums, and the 3 indexes. Then the first migration and `prisma/seed.ts` with synthetic data: 1–2 health centres, a supervisor, 3 CHWs, and the placeholder danger signs.
- `src/app.ts` (Express, JSON, error handler), `src/auth/` (`POST /auth/login` for phone + PIN or email + password, `POST /auth/refresh`; JWTs of 15 min and 30 d; argon2id), `src/middleware/requireRole.ts`, `GET /health`. All request bodies are validated with **zod** at the boundary.
- Tests (Jest + Supertest): login success and failure, an expired token returns 401, a role mismatch returns 403.

### 2. SMS codec (TS + Dart)
- `shared/sms-vectors.json` holds key, nonce, plaintext, and expected base64 and SMS text, plus the two-part cases and tampered-tag cases.
- TS: `server/src/sms/codec.ts`, with AES-256-GCM from `node:crypto` and the Backend Schema §3 format `HB1 <device> <b64(nonce|ct|tag)>`, plus 1/2 part headers.
- Dart: `lib/core/sms/codec.dart`, using the `cryptography` package with the same format.
- Both test suites load the same vectors file, so CI fails if the two languages ever disagree.

### 3. SMS round-trip (server)
- `POST /devices/register`: issues a device ID and a 32-byte key once; `sms_key` is encrypted at rest with `SMS_KEY_ENC_KEY`; records `build_flavor`.
- `POST /webhooks/sms`:
  1. Shared-secret check.
  2. Log the message to `sms_messages`, whose UNIQUE (device_id, nonce) rejects replays.
  3. Reassemble two-part messages, then decrypt.
  4. Upsert a partial visit (`source='sms'`, `is_partial=true`) and its alert.
  5. Send `HB OK <code>` through the Africa's Talking SDK.
  6. Tampered messages and unknown devices are logged and get no reply.
- `POST /webhooks/sms/delivery` updates the outbound status.
- Tests: Supertest with the AT client mocked, plus one manual run on the AT sandbox simulator.

### 4. Flutter data layer (`lib/data/`, `lib/core/`)
- Packages: `flutter_riverpod`, `drift` + `drift_dev` + `build_runner`, `sqlcipher_flutter_libs`, `flutter_secure_storage`, `uuid`, `http`.
- `lib/data/db.dart`: drift with the 8 tables from Backend Schema §2, opened with SQLCipher. Its key is generated once and stored in `flutter_secure_storage`.
- Repositories (`patients`, `visits`, `drafts`, `danger_signs`):
  - Every create or update writes the entity and its outbox row **in one transaction**.
  - UUID v4 ids are generated on the phone.
  - `short_code` is the first 8 hex characters of the UUID.
- `lib/data/forms/`: validation ranges (temperature, MUAC, gestational weeks from the docs, plus the rest once Figma is readable) and `isUrgent(signs)`.
- Riverpod providers for every repository, plus `lib/data/README.md`: the **contract the UI owner wires the screens to** (provider names, models, sync-state enum `local | queued | synced | failed`).
- Tests: repository unit tests on an in-memory drift DB, including "the entity and outbox row commit or roll back together".

### 5. Sync engine
- Server:
  - `POST /sync/push`: idempotent upsert by UUID, in order, batches of 50. A full record that arrives after its SMS merges into the partial visit (FR-14).
  - `GET /sync/pull?since=`: patients, alert statuses and danger signs changed since the last pull.
  - Conflicts follow TRD §4: the server owns status, the phone owns visit content, and patients are last-write-wins with an `audit_log` entry.
- App (`lib/sync/`):
  - Reachability check with `HEAD /health` and a 5 s timeout. Triggers: `connectivity_plus` changes, app resume, and `workmanager` every 30 min.
  - Back-off 30 s → 2 min → 10 min → 30 min, stored in `outbox.next_try_at`.
- Tests:
  - Supertest pushes the same batch twice and gets one row.
  - On a real device, `integration_test/sync_test.dart` records 20 visits offline, kills the app, reboots, and checks that all 20 sync exactly once.

### 6. Urgent pathway
- Server: `POST /alerts` (internet channel).
- App (`lib/urgent/`):
  - Try `POST /alerts` with a 10 s timeout. On failure, encode the visit with the slice-2 codec and hand it to `UrgentSender`.
  - `ComposerSender` (store build) opens a pre-filled `sms:` link with `url_launcher`.
  - `DirectSmsSender` (managed build) uses a **~50-line Kotlin MethodChannel in `android/app/src/managed/kotlin/`**: `SmsManager.sendTextMessage` plus a receiver that reads the `HB OK` ack. This deliberately avoids an SMS plugin, because a plugin's manifest would merge `SEND_SMS` into the store build and Play would reject it.
- `urgent_dispatch` states: `sending → sent_sms → confirmed | unconfirmed`. After 10 minutes without an ack the state becomes `unconfirmed`, and the app offers Resend and the `tel:` call fallback. In the store build, "I got the confirmation" sets `confirmed`.
- Tests: sender selection per flavour, the state machine, and a real-SIM run with the managed build in airplane mode plus SIM.

### 7. Supervisor dashboard
- Server: `GET /alerts?status=`, `GET /alerts/:id`, `PATCH /alerts/:id` (writes to `alert_events` and `audit_log`), `GET /chws` (last sync, pending count). Supervisors see only their own health centre.
- `dashboard/`:
  - Login goes through a Next.js route handler that keeps the tokens in an httpOnly cookie.
  - Inbox with 10 s polling, status filters, channel badge, and a "Full record pending" tag.
  - Case detail with the actions at the bottom; the CHW list.
- Tests: Vitest component tests, and Supertest for the scoping rule that supervisor A can't read centre B's alerts.

### 8. Release
- Two Vercel projects: `server/` with the Neon env vars, and `dashboard/` with `API_URL`. Migrations run in CI against production on tag.
- A release job on tag builds `flutter build appbundle --flavor store` and `flutter build apk --flavor managed`, signed with the keystore from secrets, attached to the GitHub release.
- Demo seed data.

## What I need from you
1. **Revoke the leaked token now.** The old `HealthBridge` repo's remote URL contains a GitHub personal access token in plain text. Revoke it at GitHub → Settings → Developer settings → Tokens. For pushing to `HealthBridge_v2`, sign in through Git Credential Manager (a browser prompt on first push), and never put a token in the URL.
2. **Figma access.** The connected Figma account only has *view* access, and the Figma MCP needs *edit* access. Ask the file owner to share edit access with the team account, or move the file into "TEAM 6", where that account has a Full seat. I need it for the 4 visit forms' fields and ranges and for the danger-sign list. Until then I seed a clearly marked placeholder list, which blocks nothing before slice 4.
3. **Accounts** (you sign in yourself; I never enter credentials):
   - Vercel, with Neon Postgres added from the Marketplace before slice 8.
   - Africa's Talking sandbox: give me the username, sandbox API key and shortcode via a local `.env`, not chat. Needed in slice 3.
4. **Local tools:**
   - PostgreSQL 16 for Windows (EDB installer): create a `healthbridge` DB.
   - `flutter doctor` showing Android SDK and JDK green (java isn't on PATH).
   - Node: you have v26, so I'll pin `"engines": ">=20"` and use v26 locally. Vercel runs Node 22.
5. **Hardware:** one Android phone with a SIM and USB debugging on, for slices 3, 5 and 6.
6. **Release keystore** for the managed APK, needed in slice 8; I'll give you the `keytool` command.
7. **Each push:** I ask before every `git push` and PR.

## Verification
- Every slice: CI green on the PR (flutter analyze and test, server jest, dashboard vitest and build), with both codecs passing `shared/sms-vectors.json`.
- Slice 3: AT simulator SMS → alert row → ack. Slice 5: the 20-visit kill and reboot test on a device. Slice 6: airplane mode plus SIM with the managed build; the CI manifest check shows the store build has no `SEND_SMS`.
- Slice 8: clean installs of both builds on a fresh phone against the Vercel API; the dashboard shows the alert within 10 s.

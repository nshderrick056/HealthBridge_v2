# HealthBridge Rwanda — Technical Requirements Document

Oct 6, 2026 · @GATETE Derrick

HealthBridge is an Android Flutter app with a local SQLite outbox, a Node.js/Express API on PostgreSQL, an Africa's Talking SMS webhook, and a Next.js supervisor dashboard. Every record is written on the phone first; the network is never assumed.

## 1. Architecture

Two pathways end in the same API and database. The routine path is HTTPS sync from the phone's outbox; the urgent path tries HTTPS first and falls back to an encoded SMS that the gateway posts to the API as a webhook.

&#91;embedded content: System architecture · two pathways, one API\]

The acknowledgement SMS travels back to the CHW the same way.

## 2. Stack decisions

| Layer | Choice | Why |
| --- | --- | --- |
| Mobile | Flutter (pinned stable), Android only | Team skill; iOS cannot send SMS from an app |
| State | Riverpod | Testable, simple async state |
| Local DB | drift (SQLite) + SQLCipher | Relational queries, migrations, encrypted at rest |
| Background work | workmanager | Periodic and connectivity-triggered sync |
| Connectivity | connectivity\_plus + a real reachability check (HEAD /health, 5 s) | Wi-Fi "connected" does not mean internet |
| Crypto | cryptography package (Dart), node:crypto (TS), AES-256-GCM | Authenticated encryption, small overhead |
| Backend | Node.js 20 LTS, Express, TypeScript, Prisma | Typed, migrations |
| Database | PostgreSQL 16 | Relational integrity, JSONB for form answers |
| SMS gateway | Africa's Talking (sandbox in development) | Rwanda coverage, inbound SMS webhook, delivery reports |
| Dashboard | Next.js + Tailwind, polling every 10 s | Near-real-time without WebSocket infrastructure |
| Auth | JWT access (15 min) + refresh (30 days); argon2id hashes | Offline-friendly sessions |
| Hosting | Render or Railway + managed Postgres | Free tiers fit the project |
| Build flavours | Flutter flavours store and managed, separate application IDs | Same code; SMS permission only in the managed build (Section 3) |

## 3. SMS sending: the platform limit and our approach

One Flutter codebase produces two builds, released together from one CI run but installed by different routes. The **store** build goes on Google Play and never sends an SMS by itself. The **managed** build is an APK installed by the health programme (sideload or MDM) and sends the SMS automatically with the SEND\_SMS permission. Google Play only lets default SMS apps use SEND\_SMS, which is why the managed build is never uploaded to the Play Store; iOS never allows an app to send an SMS on its own.

| Option | Allowed on Play Store | CHW effort | Use in HealthBridge |
| --- | --- | --- | --- |
| A. Pre-filled SMS composer (sms: intent via url\_launcher) | Yes | One tap on Send | **Store build** |
| B. Direct send with SEND\_SMS, APK installed by the health programme (sideload or MDM) | No (not on Play) | None, fully automatic | **Managed build**; used for the demo and for programme-issued phones |
| C. USSD session via Africa's Talking (app opens the dialer on a \*code#) | Yes, needs no SMS permission | Answers 2 to 4 short menu steps | Stretch goal; also works on basic phones |
| D. Apply for a Play SEND\_SMS exception | Only if Google approves | None | Not relied on |
| E. Phone call to the supervisor (tel: intent) | Yes | Talks | Last resort when no confirmation arrives |

**Two builds, one codebase**

|  | Store build | Managed build |
| --- | --- | --- |
| Flutter flavour | `store` | `managed` |
| Application ID | `rw.healthbridge.app` | `rw.healthbridge.app.managed` (applicationIdSuffix) |
| SMS permissions | None | SEND\_SMS, RECEIVE\_SMS |
| Urgent SMS | SMS app opens pre-filled, CHW taps Send | Sent automatically; acknowledgement read automatically |
| Distribution | Google Play (.aab) | APK installed by the health programme: direct download, USB copy, or MDM (Android Enterprise, Knox) |
| Build command | `flutter build appbundle --flavor store` | `flutter build apk --flavor managed` |
| Intended phones | CHW's own phone or any public install | Programme-issued phones and the demo |

**Rules for the two builds**

1. One interface, `UrgentSender`, with two implementations: `ComposerSender` (store) and `DirectSmsSender` (managed), chosen by flavour.
2. SEND\_SMS and RECEIVE\_SMS are declared only in the managed flavour's manifest (`android/app/src/managed/AndroidManifest.xml`), never in the main manifest. If they leak into the main manifest, the Play upload is rejected. CI checks this on every build.
3. Both builds come from the same commit and the same CI run and share one version number: the `.aab` goes to Google Play, the `.apk` is attached to the release for the health programme.
4. The managed APK is signed with the team's own release key, kept in CI secrets. Whoever installs it must allow installs from unknown sources once, or the MDM pushes it.
5. The two builds have different application IDs and are never installed on the same phone; the programme decides which build each phone gets. The Profile screen shows "Build: store" or "Build: managed".
6. The backend does not care which build sent an SMS. The device registers its build flavour once, so supervisors and the team can tell them apart.
7. In the store build, the CHW sees the acknowledgement SMS in her inbox and taps "I got the confirmation", or the alert is marked confirmed on the next sync.

What to say in the defence: "Fully automatic SMS works on phones where the health programme installs our managed build; on Google Play it is one tap, and either way it beats walking uphill for signal."

## 4. Offline and sync rules

1. Every create or update writes the entity and an outbox row in one SQLite transaction.
2. Every entity has a UUID v4 generated on the phone; the server upserts by that UUID, so retries are safe.
3. Sync pushes the outbox in order in batches of 50, then pulls changes since the last server timestamp.
4. Conflicts: the server owns case status (set by supervisors); the phone owns visit content; patient details use last-write-wins with an audit log.
5. Retry back-off: 30 s, 2 min, 10 min, then every 30 min; also on connectivity change and app resume.
6. Each record shows one state: Saved on phone, Waiting to sync, Synced, Sync failed.

## 5. Urgent pathway

1. Visit saved with is\_urgent = true.
2. App posts it to /alerts over HTTPS with a 10 s timeout.
3. On failure, the app builds and encrypts the SMS payload and hands it to `UrgentSender` (Section 3).
4. Status: "Sent by SMS, waiting for confirmation".
5. Gateway posts the inbound SMS to /webhooks/sms; the server picks the device key, decrypts, rejects reused nonces, creates or updates the alert.
6. Server replies with an acknowledgement SMS carrying the short alert code.
7. No confirmation in 10 min: the app offers Resend and Call supervisor.
8. When data returns, the full record syncs and attaches to the same alert by UUID.

## 6. Security and privacy

- Each device gets a random 256-bit key at registration, kept in Android Keystore (flutter\_secure\_storage) and on the server.
- SMS: AES-256-GCM, 12-byte nonce, 16-byte tag; device ID in clear so the server can pick the key; no names in the SMS.
- TLS 1.2+ for all API traffic; PINs and passwords hashed with argon2id.
- Role-based access: a CHW sees only her patients; a supervisor sees only her health centre.
- Audit log on every alert status change.

## 7. Testing

- Unit tests for payload encode/decode and encryption, with shared test vectors between Dart and TypeScript.
- Integration test: airplane mode, record 20 visits, kill app, reboot, restore data; all 20 synced exactly once.
- SMS: Africa's Talking simulator for inbound and outbound; one real-SIM test with the managed build.
- API tests with Jest + Supertest; dashboard component tests with Vitest.

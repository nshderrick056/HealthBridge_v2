# HealthBridge Rwanda — Technical Requirements Document

Oct 6, 2026 · @GATETE Derrick · **Updated Nov 2026: the database and sign-in moved from PostgreSQL and JWT to Cloud Firestore and Firebase Authentication. Sections 1, 2, 4, 5, 6 and 7 below describe the system as built.**

HealthBridge is an Android Flutter app with a local SQLite outbox, a Cloud Firestore database protected by security rules, a small Node.js/Express server on the Firebase Admin SDK, an Africa's Talking SMS webhook, and a Next.js dashboard for supervisors and admins. Every record is written on the phone first; the network is never assumed.

## 1. Architecture

Two pathways end in the same Firestore database. The routine path is sync from the phone's outbox, written straight to Firestore under the signed-in user's account and the security rules; the urgent path tries Firestore first and falls back to an encoded SMS that the gateway posts to the Express server as a webhook. The server decrypts it and writes a partial case; the full visit merges into the same case when it syncs.

&#91;embedded content: System architecture · two pathways, one database\]

The acknowledgement SMS travels back to the CHW the same way.

## 2. Stack decisions

| Layer | Choice | Why |
| --- | --- | --- |
| Mobile | Flutter (pinned stable), Android only | Team skill; iOS cannot send SMS from an app |
| State | Riverpod | Testable, simple async state |
| Local DB | drift (SQLite) + SQLCipher | Relational queries, migrations, encrypted at rest |
| Background work | workmanager | Periodic and connectivity-triggered sync |
| Connectivity | connectivity\_plus + a real reachability check (HEAD /health, 5 s) | Wi-Fi "connected" does not mean internet |
| Crypto | cryptography package (Dart), node:crypto (TS), AES-256-GCM, HMAC-SHA256 for acknowledgements | Authenticated encryption, small overhead |
| Backend | Node.js 20 LTS, Express, TypeScript, Firebase Admin SDK | Typed; does only what an app must not do itself |
| Database | Cloud Firestore (project `healthbridge-rwanda`) with security rules and indexes | Real-time, owner-limited rules, no database server to run |
| SMS gateway | Africa's Talking (sandbox in development) | Rwanda coverage, inbound SMS webhook, delivery reports |
| Dashboard | Next.js, polling every 10 s | Near-real-time without WebSocket infrastructure |
| Auth | Firebase Authentication: phone + PIN (server checks an argon2id hash and issues a custom token), SMS code, email + password; role and health centre as custom claims | Three sign-in ways, sessions that survive a restart |
| Hosting | Vercel for the server and the dashboard; Firebase for data and sign-in | Free tiers fit the project |
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
2. Every entity has a UUID v4 generated on the phone and is written to the Firestore document with the same ID, so a write repeated after a dropped connection lands on the same document.
3. Sync writes the outbox in order to Firestore as the signed-in CHW (the security rules decide what is allowed), then reads the CHW's patients, alert confirmations and danger signs. Firestore's own offline cache is switched off because it is not encrypted; offline storage is the SQLCipher database.
4. Conflicts: the server owns case status (set by supervisors through the server); the phone owns visit content; patient details use last-write-wins by `updatedAt`.
5. Retry back-off: 30 s, 2 min, 10 min, then every 30 min; also on connectivity change and app resume.
6. Each record shows one state: Saved on phone, Waiting to sync, Synced, Sync failed.
7. One CHW's records per phone: another CHW can sign in only after everything has uploaded.

## 5. Urgent pathway

1. Visit saved with isUrgent = true (the rules require isUrgent to equal "danger signs not empty").
2. App writes the visit and its alert to Firestore together, with a 10 s timeout.
3. On failure, the app builds and encrypts the SMS payload and hands it to `UrgentSender` (Section 3).
4. Status: "Sent by SMS, waiting for confirmation".
5. Gateway posts the inbound SMS to /webhooks/sms; the server picks the device key, decrypts, rejects reused nonces, creates or updates the alert.
6. Server replies with an acknowledgement SMS `HB OK <code> <tag>`; the tag is an HMAC the app checks, so only the server can confirm.
7. No confirmation in 10 min: the app offers Resend and Call supervisor.
8. When data returns, the full record syncs and merges into the same alert by UUID.

## 6. Security and privacy

- Each device gets a random 256-bit key at registration, kept in Android Keystore (flutter\_secure\_storage) and on the server (wrapped with a server key, in a server-only collection).
- SMS: AES-256-GCM, 12-byte nonce, 16-byte tag; device ID in clear so the server can pick the key; no names in the SMS.
- TLS 1.2+ for all traffic; PINs hashed with argon2id in a collection no app can read; five wrong PINs lock the account for 15 minutes; forgot-PIN uses a one-time code (30 minutes, five tries) approved by an admin.
- Firestore security rules: a CHW reads and writes only their own patients and visits; a supervisor reads only their own health centre; roles come from custom claims that only the server can set; health records are never deleted, only archived.
- Audit log on every alert status change, account change and reset.

## 7. Testing

- Unit tests for payload encode/decode and encryption, with shared test vectors between Dart and TypeScript.
- Flutter widget and layout tests, including every main screen at four sizes (320x568, 430x932, landscape, landscape with extra-large text).
- Integration test: airplane mode, record 20 visits, kill app, reboot, restore data; all 20 synced exactly once.
- SMS: Africa's Talking simulator for inbound and outbound; one real-SIM test with the managed build.
- Server tests with Vitest + Supertest against the Firebase Auth and Firestore emulators; dashboard component tests with Vitest.

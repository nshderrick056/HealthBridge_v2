# HealthBridge Rwanda — Backend Schema

Oct 6, 2026 · @GATETE Derrick · **Updated Nov 2026: the backend is Cloud Firestore and Firebase Authentication. The original PostgreSQL design was replaced; the full entity-relationship diagram is in `docs/ERD.md` and the rules are in `firestore.rules`.**

Cloud Firestore holds the shared records; the phone mirrors the clinical ones in SQLite plus an outbox. Every clinical record is keyed by a UUID created on the phone, which makes retries and the SMS-then-sync merge safe: a write repeated after a dropped connection lands on the same document.

## 1. Cloud Firestore (shared database)

Project `healthbridge-rwanda`. Field names are camelCase and are exactly the names checked by `firestore.rules`. Firestore has no joins or foreign-key constraints, so the relationships below are kept by the app and the server and checked by the security rules.

| Collection | Holds | Main fields |
| --- | --- | --- |
| `healthCenters` | Facilities and the supervisor call-back number | `name`, `district`, `sector`, `callNumber` |
| `users` | CHWs, supervisors, admins; the document ID is the Firebase Auth UID | `role`, `chwRole`, `fullName`, `phone`, `email`, `healthCenterId`, `village`, `language`, `active`, `createdAt` |
| `devices` | Registered phones and which build (store or managed) each runs | `userId`, `buildFlavor`, `lastSyncAt`, `revokedAt` |
| `patients` | Patients, keyed by a phone-generated UUID | `shortId`, `chwId`, `healthCenterId`, `fullName`, `sex`, `birthDate`, `ageEstimate`, `village`, `phone`, `consentAt`, `createdAt`, `updatedAt`, `archivedAt` |
| `visits` | Visit records, form answers as a map | `shortCode`, `patientId`, `chwId`, `healthCenterId`, `deviceId`, `type`, `answers`, `notes`, `isUrgent`, `dangerSigns`, `followUpOn`, `recordedAt`, `receivedAt`, `source`, `isPartial` |
| `dangerSigns` | Reference list of sign codes in EN and RW | `visitType`, `labelEn`, `labelRw` |
| `alerts` | One alert per urgent visit (same ID as the visit) | `visitId`, `chwId`, `healthCenterId`, `channel`, `status`, `createdAt`, `ackedToChwAt` |
| `alerts/{id}/events` | Status history of each alert (sub-collection) | `actorId`, `fromStatus`, `toStatus`, `note`, `createdAt` |

Server-only collections (the security rules close them to every app; only the Express server reads and writes them through the Admin SDK): `credentials` (argon2id PIN hash, failed-login count, lock time), `deviceKeys` (the AES key of each device, wrapped with a server key), `resetRequests` (forgot-PIN requests and hashed one-time codes), `smsMessages` (every inbound and outbound SMS, for replay protection and debugging) and `auditLog` (who changed what).

**Rules that matter** (see `firestore.rules`):

- A CHW reads and writes only their own patients and visits; a supervisor reads only the records of their own health centre. The role and `healthCenterId` come from custom claims in the sign-in token, which only the server can set.
- Only the listed keys are allowed on a patient or visit, and `isUrgent` must equal "`dangerSigns` is not empty".
- After creation, `chwId`, `healthCenterId`, `shortId` and `createdAt` cannot change.
- Nothing can be deleted: a patient is archived by setting `archivedAt`.

**Indexes** (`firestore.indexes.json`): alerts by `healthCenterId`, `status` and `createdAt` (the supervisor inbox); alerts by `healthCenterId` and `createdAt`; visits by `chwId` and `recordedAt`; users by `healthCenterId` and `role`.

## 2. SQLite (phone, drift)

| Table | Key columns | Purpose |
| --- | --- | --- |
| patients | id, short\_id, full\_name, sex, birth\_date, village, sync\_state | Offline patient list and search |
| visits | id, short\_code, patient\_id, type, answers\_json, is\_urgent, recorded\_at, sync\_state | Visit records |
| visit\_danger\_signs | visit\_id, code | Ticked signs |
| outbox | id, entity, entity\_id, op, payload\_json, attempts, next\_try\_at, last\_error | Ordered upload queue |
| urgent\_dispatch | visit\_id, channel, state, sent\_at, confirmed\_at | Drives the urgent status screens |
| drafts | id, screen, data\_json, updated\_at | Autosave for half-filled forms |
| sync\_meta | key, value | Last pull timestamp, tokens |
| danger\_signs | code, visit\_type, label\_en, label\_rw | Shipped with the app, refreshed on sync |

`sync_state` is one of local, queued, synced, failed. `urgent_dispatch.state` is one of sending, sent\_sms, confirmed, unconfirmed. The database is encrypted with SQLCipher. The exact tables are in `lib/data/db.dart`.

## 3. SMS payload

One SMS of at most 160 GSM-7 characters:

```
HB1 D0042 <base64( nonce[12] | AES-256-GCM(plaintext) | tag[16] )>
```

Plaintext, semicolon separated (about 50 bytes):

```
A;7f3c9a21;P0412;M;2610062114;HB,CV;T389;G32
```

| Field | Example | Meaning |
| --- | --- | --- |
| Kind | A | A = alert |
| Short code | 7f3c9a21 | First 8 hex of the visit UUID |
| Patient | P0412 | Patient short ID, never a name |
| Visit type | M | M maternal, C child, L malaria, N nutrition |
| Time | 2610062114 | YYMMDDHHmm, phone time |
| Signs | HB,CV | Danger-sign codes |
| Vitals | T389;G32 | Temperature 38.9 °C, 32 weeks (type-specific, optional) |

Size: 50 bytes + 28 bytes of nonce and tag = 78 bytes, about 104 Base64 characters, plus a 10-character header, about 114 characters. A longer payload is sent as two parts with a "1/2" header and reassembled before decrypting.

Acknowledgement from the server, plain text: `HB OK <code> <tag>`, where the tag is the first 12 hex characters of an HMAC-SHA256 over `HB OK <code>` with the device key, so only the server can confirm an alert (no patient data in the message).

## 4. Server API (Express on the Firebase Admin SDK)

The phone reads and writes Firestore directly, under the security rules, for patients and visits and for an urgent alert sent over the internet. The Express server handles what an app must not do itself: checking PIN hashes, issuing sign-in tokens, creating accounts, changing case status, and receiving SMS. Email + password and SMS-code sign-in are done by Firebase Authentication directly.

| Method | Path | Who | Purpose |
| --- | --- | --- | --- |
| POST | /auth/pin | All | Phone + PIN; returns a Firebase custom token with role and health-centre claims; 5 wrong tries lock the account for 15 minutes |
| POST | /auth/change | Signed-in user | First sign-in: replace the temporary PIN or password, which clears the must-change claim |
| POST | /auth/reset/request | All | Ask for a PIN or password reset (an admin must approve) |
| POST | /auth/reset/verify | All | Check the one-time code (30 minutes, 5 tries) |
| POST | /auth/reset/complete | All | Set the new PIN or password; other sessions are signed out |
| POST | /devices/register | CHW | Bind a device and its build flavour (store or managed), receive device ID and SMS key once |
| POST | /visits/:id/merge-sms | CHW | Attach a full visit to the case created from its SMS |
| POST | /webhooks/sms | Gateway | Inbound SMS (shared-secret check) |
| POST | /webhooks/sms/delivery | Gateway | Delivery reports for outbound SMS |
| GET | /alerts?status= | Supervisor | Alert inbox for their own health centre |
| GET | /alerts/:id | Supervisor | Case detail with visit and events |
| PATCH | /alerts/:id | Supervisor | Change status (allowed moves only, inside a transaction) and add a note |
| GET | /chws, /chws/:id | Supervisor | CHWs with last sync, pending count and visit history |
| GET | /patients, /patients/:id | Supervisor | Patients of their health centre and a patient's history |
| GET, POST | /admin/users | Admin | List members; create an account (a temporary PIN or password is texted) |
| GET, PATCH, DELETE | /admin/users/:id | Admin | Member details; deactivate or reactivate; delete |
| GET, POST | /admin/health-centers | Admin | List and add health centres |
| GET | /admin/health-centers/:id | Admin | A centre's details |
| GET | /admin/reset-requests | Admin | Pending reset requests |
| POST | /admin/reset-requests/:id/approve | Admin | Approve a reset; the one-time code is texted |
| GET | /health | Public | Reachability check for the app |

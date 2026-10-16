# HealthBridge Rwanda — Backend Schema

Oct 6, 2026 · @GATETE Derrick

Eleven PostgreSQL tables hold the MVP; the phone mirrors the clinical ones in SQLite plus an outbox. Every clinical row is keyed by a UUID created on the phone, which makes retries and the SMS-then-sync merge safe.

## 1. PostgreSQL (server)

| Table | Holds |
| --- | --- |
| health\_centers | Facilities and the supervisor call-back number |
| users | CHWs, supervisors, admins |
| devices | Registered phones, their SMS keys, and which build (store or managed) each runs |
| patients | Patients, keyed by phone-generated UUID |
| visits | Visit records, form answers as JSONB |
| danger\_signs | Reference list of sign codes in EN and RW |
| visit\_danger\_signs | Signs ticked on each visit |
| alerts | One alert per urgent visit, with status |
| alert\_events | Status history of each alert |
| sms\_messages | Every inbound and outbound SMS, for replay protection and debugging |
| audit\_log | Who changed what |

```sql
CREATE TABLE health_centers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  district    TEXT NOT NULL,
  sector      TEXT NOT NULL,
  call_number TEXT                          -- supervisor phone for "call" fallback
);

CREATE TYPE user_role AS ENUM ('chw', 'supervisor', 'admin');
CREATE TYPE chw_role  AS ENUM ('asm', 'binome');

CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role             user_role NOT NULL,
  chw_role         chw_role,
  full_name        TEXT NOT NULL,
  phone            TEXT UNIQUE NOT NULL,
  email            TEXT UNIQUE,
  secret_hash      TEXT NOT NULL,           -- argon2id of PIN or password
  health_center_id UUID REFERENCES health_centers(id),
  village          TEXT,
  language         TEXT NOT NULL DEFAULT 'rw',
  active           BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE devices (
  id           TEXT PRIMARY KEY,            -- short ID, e.g. 'D0042', sent in clear in SMS
  user_id      UUID NOT NULL REFERENCES users(id),
  sms_key      BYTEA NOT NULL,              -- 32-byte AES key, encrypted at rest
  sim_phone    TEXT,
  build_flavor TEXT NOT NULL DEFAULT 'store' CHECK (build_flavor IN ('store','managed')),
  last_sync_at TIMESTAMPTZ,
  revoked_at   TIMESTAMPTZ
);

CREATE TABLE patients (
  id           UUID PRIMARY KEY,            -- generated on the phone
  short_id     TEXT UNIQUE NOT NULL,        -- e.g. 'P0412', safe for SMS
  chw_id       UUID NOT NULL REFERENCES users(id),
  full_name    TEXT NOT NULL,
  sex          CHAR(1) CHECK (sex IN ('F','M')),
  birth_date   DATE,
  age_estimate SMALLINT,
  village      TEXT NOT NULL,
  phone        TEXT,
  consent_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL
);

CREATE TYPE visit_type AS ENUM ('maternal', 'child', 'malaria', 'nutrition');

CREATE TABLE visits (
  id           UUID PRIMARY KEY,            -- generated on the phone
  short_code   TEXT NOT NULL,               -- first 8 hex of id, used in SMS
  patient_id   UUID NOT NULL REFERENCES patients(id),
  chw_id       UUID NOT NULL REFERENCES users(id),
  device_id    TEXT NOT NULL REFERENCES devices(id),
  type         visit_type NOT NULL,
  answers      JSONB NOT NULL DEFAULT '{}',
  notes        TEXT,
  is_urgent    BOOLEAN NOT NULL DEFAULT false,
  follow_up_on DATE,
  recorded_at  TIMESTAMPTZ NOT NULL,        -- phone clock
  received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  source       TEXT NOT NULL CHECK (source IN ('sync','sms')),
  is_partial   BOOLEAN NOT NULL DEFAULT false, -- true until the full record syncs
  UNIQUE (device_id, short_code)
);

CREATE TABLE danger_signs (
  code       CHAR(2) PRIMARY KEY,           -- e.g. 'HB' heavy bleeding
  visit_type visit_type NOT NULL,
  label_en   TEXT NOT NULL,
  label_rw   TEXT NOT NULL
);

CREATE TABLE visit_danger_signs (
  visit_id UUID REFERENCES visits(id) ON DELETE CASCADE,
  code     CHAR(2) REFERENCES danger_signs(code),
  PRIMARY KEY (visit_id, code)
);

CREATE TYPE alert_status AS ENUM ('new','reviewed','escalated','follow_up','resolved');

CREATE TABLE alerts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id         UUID UNIQUE NOT NULL REFERENCES visits(id),
  health_center_id UUID NOT NULL REFERENCES health_centers(id),
  channel          TEXT NOT NULL CHECK (channel IN ('internet','sms')),
  status           alert_status NOT NULL DEFAULT 'new',
  acked_to_chw_at  TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE alert_events (
  id          BIGSERIAL PRIMARY KEY,
  alert_id    UUID NOT NULL REFERENCES alerts(id),
  actor_id    UUID REFERENCES users(id),
  from_status alert_status,
  to_status   alert_status NOT NULL,
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sms_messages (
  id         BIGSERIAL PRIMARY KEY,
  direction  TEXT NOT NULL CHECK (direction IN ('in','out')),
  phone      TEXT NOT NULL,
  device_id  TEXT REFERENCES devices(id),
  nonce      BYTEA,                         -- unique per device, blocks replays
  raw_text   TEXT NOT NULL,
  status     TEXT NOT NULL,                 -- parsed, rejected, sent, delivered, failed
  error      TEXT,
  gateway_id TEXT,
  visit_id   UUID REFERENCES visits(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (device_id, nonce)
);

CREATE TABLE audit_log (
  id         BIGSERIAL PRIMARY KEY,
  actor_id   UUID REFERENCES users(id),
  action     TEXT NOT NULL,
  entity     TEXT NOT NULL,
  entity_id  TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON visits (chw_id, recorded_at DESC);
CREATE INDEX ON alerts (health_center_id, status, created_at DESC);
CREATE INDEX ON patients (chw_id, village);
```

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

`sync_state` is one of local, queued, synced, failed. `urgent_dispatch.state` is one of sending, sent\_sms, confirmed, unconfirmed.

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

Acknowledgement from the server, plain text: `HB OK 7f3c9a21` (no patient data).

## 4. API endpoints

| Method | Path | Who | Purpose |
| --- | --- | --- | --- |
| POST | /auth/login | All | Phone + PIN or email + password, returns tokens |
| POST | /auth/refresh | All | New access token |
| POST | /devices/register | CHW | Bind device and its build flavour (store or managed), receive device ID and SMS key once |
| POST | /sync/push | CHW | Upload outbox batch, idempotent by UUID |
| GET | /sync/pull?since= | CHW | Patients, alert statuses, danger-sign list changed since |
| POST | /alerts | CHW | Urgent visit over internet |
| POST | /webhooks/sms | Gateway | Inbound SMS (shared-secret check) |
| POST | /webhooks/sms/delivery | Gateway | Delivery reports for outbound SMS |
| GET | /alerts?status= | Supervisor | Alert inbox for own health centre |
| GET | /alerts/:id | Supervisor | Case detail with visit and events |
| PATCH | /alerts/:id | Supervisor | Change status, add note |
| GET | /chws | Supervisor | CHWs with last sync and pending count |
| GET | /health | Public | Reachability check for the app |

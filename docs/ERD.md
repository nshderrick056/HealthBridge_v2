# HealthBridge ERD

Drawn from the live schema, [server/prisma/schema.prisma](../server/prisma/schema.prisma) (PostgreSQL), so it
matches the implemented database: same tables, column names, keys and relationships. GitHub renders the
Mermaid diagram below; paste it into [mermaid.live](https://mermaid.live) to export a PNG for the report.

`PK` primary key, `FK` foreign key, `UK` unique. CHECK constraints (in the migration SQL) are noted in comments.

```mermaid
erDiagram
    health_centers ||--o{ users : "employs"
    health_centers ||--o{ alerts : "receives"
    users ||--o{ devices : "registers"
    users ||--o{ patients : "cares for (chw)"
    users ||--o{ visits : "records (chw)"
    users |o--o{ alert_events : "acts on (actor)"
    users |o--o{ audit_log : "acts (actor)"
    patients ||--o{ visits : "has"
    devices ||--o{ visits : "sent from"
    devices |o--o{ sms_messages : "sends / receives"
    visits ||--o{ visit_danger_signs : "ticks"
    danger_signs ||--o{ visit_danger_signs : "ticked as"
    visits ||--o| alerts : "raises (if urgent)"
    visits |o--o{ sms_messages : "carried by"
    alerts ||--o{ alert_events : "history"

    health_centers {
        uuid id PK
        text name
        text district
        text sector
        text call_number "nullable, the Call fallback"
    }
    users {
        uuid id PK
        user_role role "chw | supervisor | admin"
        chw_role chw_role "nullable, asm | binome"
        text full_name
        text phone UK
        text email UK "nullable"
        text secret_hash "argon2id of PIN or password"
        uuid health_center_id FK "nullable"
        text village "nullable"
        text language "default rw"
        boolean active
        smallint failed_logins
        timestamptz locked_until "nullable"
        timestamptz created_at
    }
    devices {
        text id PK "short, e.g. D0042, sent in SMS"
        uuid user_id FK
        bytea sms_key "AES key, encrypted at rest"
        text sim_phone "nullable"
        text build_flavor "store | managed"
        timestamptz last_sync_at "nullable"
        timestamptz revoked_at "nullable"
    }
    patients {
        uuid id PK "generated on the phone"
        text short_id UK "e.g. P3FA9C1, safe for SMS"
        uuid chw_id FK
        text full_name
        char sex "nullable, F | M"
        date birth_date "nullable"
        smallint age_estimate "nullable"
        text village
        text phone "nullable"
        timestamptz consent_at
        timestamptz created_at
        timestamptz updated_at "last write wins"
        timestamptz archived_at "nullable, the app's delete"
    }
    visits {
        uuid id PK "generated on the phone"
        text short_code "UK with device_id, first 8 hex of id"
        uuid patient_id FK
        uuid chw_id FK
        text device_id FK
        visit_type type "maternal | child | malaria | nutrition"
        jsonb answers
        text notes "nullable"
        boolean is_urgent
        date follow_up_on "nullable"
        timestamptz recorded_at "phone clock"
        timestamptz received_at
        text source "sync | sms"
        boolean is_partial "true until the full record syncs"
    }
    danger_signs {
        char code PK "e.g. HB heavy bleeding"
        visit_type visit_type
        text label_en
        text label_rw
    }
    visit_danger_signs {
        uuid visit_id PK,FK
        char code PK,FK
    }
    alerts {
        uuid id PK
        uuid visit_id FK,UK "one alert per visit"
        uuid health_center_id FK
        text channel "internet | sms"
        alert_status status "new | reviewed | escalated | follow_up | resolved"
        timestamptz acked_to_chw_at "nullable"
        timestamptz created_at
    }
    alert_events {
        bigint id PK
        uuid alert_id FK
        uuid actor_id FK "nullable"
        alert_status from_status "nullable"
        alert_status to_status
        text note "nullable"
        timestamptz created_at
    }
    sms_messages {
        bigint id PK
        text direction "in | out"
        text phone
        text device_id FK "nullable, UK with nonce"
        bytea nonce "nullable, blocks replays"
        text raw_text
        text status "parsed | rejected | part | sent | delivered | failed"
        text error "nullable"
        text gateway_id "nullable"
        uuid visit_id FK "nullable"
        timestamptz created_at
    }
    audit_log {
        bigint id PK
        uuid actor_id FK "nullable"
        text action "e.g. patient.update, patient.archive"
        text entity
        text entity_id
        timestamptz created_at
    }
```

## How the data is organised

- **One health centre, many people.** A supervisor and CHWs belong to a health centre; a supervisor only sees
  alerts for their own centre (enforced in the API, [server/src/supervisor/routes.ts](../server/src/supervisor/routes.ts)).
- **A CHW owns their patients and visits.** `patients.chw_id` and `visits.chw_id`; sync refuses a change to
  another CHW's record.
- **IDs are made on the phone.** Patients and visits get a UUID offline, so a retried upload is recognised and
  stored once.
- **An urgent visit raises one alert** (`alerts.visit_id` is unique), whether it arrived over the internet or
  by SMS; `alert_events` keeps every status change and who made it.
- **SMS log.** Every SMS in or out is in `sms_messages`; `(device_id, nonce)` is unique so a replayed SMS is
  refused.
- **Nothing is deleted.** Archiving sets `patients.archived_at`; `audit_log` records creates, updates and
  archives.

## On the phone

The app keeps its own encrypted SQLite copy (drift, [lib/data/db.dart](../lib/data/db.dart)): `patients`,
`visits` and `visit_danger_signs` mirror the tables above, plus phone-only tables: `outbox` (changes waiting to
upload), `urgent_dispatch` (each urgent alert's SMS state), `drafts` (half-filled forms), `sync_meta` and a copy
of `danger_signs`.

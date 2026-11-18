# HealthBridge Rwanda: product

HealthBridge lets community health workers (CHWs) in rural Rwanda record household visits on a phone with no
signal, and get a danger sign (for example, bleeding in pregnancy) to the nearest health centre in minutes, by
internet if there is any and by SMS if there is none. Supervisors at the health centre see those alerts and act
on them. An admin creates every account.

This file says what the product is and how the pieces fit. How to run it, release it and what is still to do is
in [README.md](README.md); the full specs are in [documents/](documents/) and the data model in
[docs/ERD.md](docs/ERD.md).

## Users

| Who | Where | What they need |
| --- | --- | --- |
| **CHW** (ASM or binôme) | Android app | Record a visit in a minute, in sunlight, one-handed, often with no signal; know at once that an urgent alert went and who to call. Their phone may be shared with a small family and is often on 2G. |
| **Supervisor** (health centre nurse or in-charge) | Android app and web dashboard | See urgent alerts the moment they arrive, whether they came by internet or SMS; move a case along (reviewed, escalated, follow-up, resolved) with a note; see each CHW's and patient's history. |
| **Admin** (system owner) | Android app and web dashboard | Create CHW and supervisor accounts (there is no self sign-up), approve PIN and password resets, add health centres, switch accounts off or delete them. |
| **Patient** | none | Never uses the product; is the subject of a record. Consent is recorded at registration. |

## What each role does

- **CHW.** Registers patients (name, age, sex, village, consent), records visits of four types (maternal, child,
  malaria, nutrition) with temperature, general condition, symptoms, notes and danger signs, reviews and saves.
  Any ticked danger sign makes the visit urgent and opens the urgent screen with one red button that sends the
  alert. Home shows today (visited, due, urgent), due follow-ups and whether visits are waiting to send. A
  patient's profile lists past visits; tapping one shows everything recorded at it. A Sync screen shows what has
  and has not reached the server, with Retry.
- **Supervisor.** Alert inbox with filters, case page with the visit, danger signs, CHW (with a Call button) and
  the next steps the server allows, a CHW list (tap one for all their visits), a Patients list with search and a
  patient page with every visit.
- **Admin.** Reset requests (approve), Members (CHW and Supervisors tabs; a member's details with Deactivate and
  Delete), Add a member, Health centres (tap one for its details and members).

## How it works

```
 Android app (Flutter)  ──►  Cloud Firestore + Firebase Auth   ◄──  Express server (Firebase Admin SDK)
   encrypted local DB            the data, under security rules        PIN sign-in, accounts, resets,
   upload queue                                                         alert status, SMS gateway
        │                                                                    ▲            ▲
        └─ urgent alert, no signal: encrypted SMS ──► Africa's Talking ──────┘            │
                                                                                           │
                                                      Web dashboard (Next.js) ─────────────┘
```

- **Offline first.** The app keeps patients and visits in an encrypted SQLite database (SQLCipher) and an upload
  queue. Nothing is lost offline; sync writes each change to Firestore, as the signed-in CHW, when there is a
  connection and in the background. One CHW's records per phone.
- **Sign-in.** Three ways: phone + PIN (the server checks the PIN and returns a Firebase custom token), phone +
  SMS code, and email + password. A new account gets a random temporary PIN or password by SMS (the admin never
  sees it) and the app makes the person choose their own before anything else. Five wrong PINs lock the account
  for 15 minutes. Forgot PIN or password: the person asks, the admin approves, the server texts a one-time code
  (30 minutes, 5 tries).
- **Urgent alert.** Online: the visit and its alert go to Firestore together within 10 seconds. Offline: the app
  sends an encrypted SMS (AES-GCM, a key unique to the phone) to the Africa's Talking number; the server decrypts
  it, creates a partial case and replies with a signed `HB OK` the phone checks. When the phone is back online it
  uploads the full visit and the server merges the two into one case. If nothing confirms after 10 minutes the app
  offers Resend and a call to the health centre.
- **Case status.** `new` to `reviewed`, `escalated`, `follow_up` or `resolved` (resolved is final). Every change
  goes through the server, which checks the move, records who made it and when, and texts the CHW on Escalate and
  Follow-up.
- **Security.** Firestore rules: a CHW reads and writes only their own patients and visits; a supervisor reads
  only their centre's; nothing is deleted from an app (records are archived); PIN hashes, device keys and reset
  requests are server-only. Supervisor and admin routes check the caller's role and centre on every call.
- **Deactivate and delete.** Deactivating switches the Firebase user off, revokes open sessions and stops PIN and
  SMS sign-in. Deleting removes the account, PIN and devices but keeps the patients and visits it recorded.

## What is where

| Part | Path | Notes |
| --- | --- | --- |
| Android app | `lib/` | Flutter, Riverpod, drift. Layers: `presentation/` (screens), `domain/`, `data/`, plus `core/` (theme, shared widgets, sign-in), `sync/`, `urgent/`. Flavours `store` (opens the SMS composer) and `managed` (sends SMS itself). |
| Server | `server/` | Express + TypeScript. Routes: `/auth`, `/admin`, supervisor (`/alerts`, `/chws`, `/patients`), `/devices`, `/visits`, `/webhooks/sms`. Tests run on the Firebase emulators. |
| Web dashboard | `dashboard/` | Next.js. Supervisor pages (alerts, CHWs, patients) and admin pages (resets, members, centres). Tokens stay in httpOnly cookies; the browser only talks to the dashboard's own `/api`. |
| Rules and indexes | `firestore.rules`, `firestore.indexes.json` | Deployed to project `healthbridge-rwanda`. |
| Shared test data | `shared/sms-vectors.json` | Both SMS codecs (TypeScript and Dart) must pass it. |

## Design

The look follows the Figma file `healthbridge-v2`, page "Prototype v3 (reference style)" and the page "Web
dashboards (v3)". An operate-mode product: scanning and speed beat expression.

- **Colour.** Brand green `#19695A` and lime `#D4FF89` lead; ink `#1D2220`; canvas `#F1F4F3`. Red `#B3261E` means
  urgent and amber `#8A5300` means due, and nothing else uses them. Inputs have a 3:1 edge.
- **Type.** Outfit, bundled in the app and the dashboard. 15 px is the floor (tab labels are the one exception).
- **Shape.** One white card per section, 24 px radius, soft shadow, never a card inside a card; 56 px pill
  buttons (dark is the main action, red only when the press sends an alert); a floating dark tab bar with a lime
  Record button; avatars carry status (red urgent, amber due).
- **Words.** Titles say what to do or what happened ("Refer Grace to the health centre today"), not a label.
  Every list has an empty state; every failure says what to do next.
- **Language.** English now. Kinyarwanda is planned and runs 20 to 40 percent longer, so titles must be able to
  wrap.

## Brand commitments

- A record is never lost and never silently dropped: it is saved on the phone first and the screen says whether
  it has been sent.
- An urgent alert is sent once, and the CHW can always tell whether it arrived.
- Colour is never the only signal; red and amber keep their meaning everywhere.
- Patient details are the minimum necessary: supervisors do not see patient phone numbers; the dashboard and
  the SMS alert carry only what triage needs.
- Accounts are made by an admin; temporary credentials are texted and replaced at first sign-in.

## State of the project

Built and tested: sign-in, offline records, sync, urgent alert by internet, supervisor inbox and case actions,
admin account and reset flows, the v3 redesign on the app and both dashboards, CHW and patient history, and
member management. Tests: Flutter, server (on the emulators) and dashboard suites all pass. The newest screens
(history, members, stat cards, redesign) have been checked by tests and, for the supervisor dashboard, in a
browser; most have not yet been tried on a phone, and the admin web pages have not been opened with a real admin
account. The offline SMS alert on the Firebase build, background sync and a live Africa's Talking number are
still to be tested. Clinical content (danger signs, ranges) is a placeholder until a clinician confirms it.

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

## Code ownership: five people

The code is split into five **vertical slices**, one per person, so that every person owns **mobile app code and
web dashboard code** (and a part of the server). Nobody works on the web only, and nobody on the app only.
Each slice is a part of the product people can see and demo: its screens in the app, its pages on the web, the
server routes behind them, and their tests.

Sizes are hand-written lines on 18 November 2026, without tests and without `lib/data/db.g.dart` (5,800 generated
lines, rebuilt by `dart run build_runner build`, never edited by hand). `lib/` is the app, `dashboard/` the web,
`server/` the server.

| Person | Slice | App (lines) | Web (lines) | Server (lines) | About |
| --- | --- | --- | --- | --- | --- |
| **1** | Sign-in, accounts and the web frame | 1,570 | 860 | 650 | 3,080 |
| **2** | Patients, visits and the records database | 2,730 | 320 | rules 150 | 3,200 |
| **3** | Urgent alerts, SMS and sync | 1,960 | 350 | 560 | 2,870 |
| **4** | Supervisor triage, home screens and history | 1,880 | 510 | 390 | 2,780 |
| **5** | Admin, design system and member management | 1,910 | 920 | 220 | 3,050 |

### Person 1: sign-in, accounts and the web frame

You can demo: signing in by PIN, SMS code and email; the temporary PIN that must be replaced; forgot PIN; the
supervisor and admin sign-in on the web; the sidebar and Sign out.

- **App:** `lib/app.dart`, `lib/main.dart`, `lib/core/auth/`, `lib/core/settings/`, `lib/presentation/auth/` (login,
  forgot, change secret and their controllers), `lib/presentation/profile/`, `lib/presentation/settings/`.
- **Web:** `dashboard/app/login/`, `dashboard/components/LoginForm.tsx`, `dashboard/lib/session.ts`,
  `dashboard/lib/proxy.ts`, `dashboard/lib/client.ts`, `dashboard/lib/types.ts`, `dashboard/proxy.ts`,
  `dashboard/app/api/` (login, logout, the forwarder), the frame: `dashboard/app/layout.tsx`, `app/page.tsx`,
  `app/globals.css`, `app/(dashboard)/layout.tsx`, `components/Shell.tsx`, `NavLinks.tsx`, `icons.tsx`, and the
  dashboard config files.
- **Server:** `server/src/accounts.ts`, `auth/`, `middleware/`, `app.ts`, `env.ts`, `firebase.ts`, `http.ts`,
  `index.ts`, `server/api/index.ts`, `server/scripts/`, `.env.example` files.
- **Tests:** `test/presentation/controllers_test.dart`, `server/test/auth.test.ts`, `server/test/emulator.ts`,
  `dashboard/test/LoginForm.test.tsx`, `dashboard/test/server.test.ts`, `dashboard/test/helpers.ts`.

### Person 2: patients, visits and the records database

You can demo: registering, editing and archiving a patient; recording a visit with danger signs; opening a past
visit; the Patients pages on the web; the rules that decide who may read what.

- **App:** `lib/data/` (`db.dart`, `db_connection*.dart`, `models.dart`, `providers.dart`, `forms/`, and the
  repositories for patients, visits, drafts, danger signs and `local_owner.dart`), `lib/domain/` (enums, the
  patient and visit repositories, use cases), `lib/presentation/patients/` (list, profile, register, visit detail),
  `lib/presentation/record/` (record, review and saved screens, `visit_form.dart`),
  `lib/presentation/view_models.dart`.
- **Web:** `dashboard/components/PatientList.tsx`, `PatientHistory.tsx`, `VisitHistory.tsx`,
  `dashboard/lib/history.ts`, `dashboard/app/(dashboard)/patients/`.
- **Server and data:** `firestore.rules`, `firestore.indexes.json`, `docs/ERD.md`.
- **Tests:** `test/data/`, `test/domain/`, `test/widget_test.dart` (recording and profile cases),
  `test/presentation/view_models_test.dart`, `dashboard/test/PatientHistory.test.tsx`.

### Person 3: urgent alerts, SMS and sync

You can demo: an urgent visit sent over the internet and, with no signal, by encrypted SMS; the `HB OK`
confirmation; Resend and Call; the Sync screen with Retry; the live alert inbox on the web.

- **App:** `lib/sync/` (engine, service, background sync, Firestore mapping), `lib/urgent/` (dispatcher, sender,
  service), `lib/core/sms/` (the codec), `lib/data/repositories/urgent_repository.dart`,
  `lib/presentation/sync/`, `lib/presentation/alerts/`, and the two screens
  `lib/presentation/record/urgent_detected_screen.dart` and `sms_alert_sent_screen.dart`.
- **Web:** `dashboard/components/AlertInbox.tsx` (the live inbox, polling every 10 s, filters, counts),
  `badges.tsx` (status, channel and pending tags), `usePolling.ts`, `dashboard/lib/format.ts`,
  `dashboard/app/(dashboard)/alerts/page.tsx`.
- **Server:** `server/src/sms/` (codec, gateway, key store, webhook), `devices/` (device keys), `visits/merge.ts`
  (SMS case plus full visit become one case).
- **Tests:** `test/sync/`, `test/urgent/`, `test/core/sms/`, `shared/sms-vectors.json`, `server/test/sms.test.ts`,
  `server/test/sms-codec.test.ts`, `dashboard/test/AlertInbox.test.tsx`, `dashboard/test/format.test.ts`.

### Person 4: supervisor triage, home screens and history

You can demo: a supervisor working an alert (reviewed, escalated, follow-up, resolved, with a note and a call to
the CHW); the CHW list and one CHW's visits; the supervisor's Patients list and a patient's history; the CHW home
with its stat cards.

- **App:** `lib/presentation/supervisor/` (inbox, case, CHWs, `history_screens.dart`, controllers),
  `lib/presentation/home/` (the CHW home, stat cards, due visits),
  `lib/data/repositories/supervision_repository.dart`, `lib/domain/entities/supervision.dart`.
- **Web:** `dashboard/components/CaseDetail.tsx`, `ChwList.tsx`, `ChwHistory.tsx`,
  `dashboard/app/(dashboard)/alerts/[id]/`, `dashboard/app/(dashboard)/chws/`.
- **Server:** `server/src/supervisor/routes.ts` (alerts, status changes, CHWs, patients, histories).
- **Tests:** the supervisor cases in `test/presentation/role_screens_test.dart`, `server/test/supervisor.test.ts`,
  `dashboard/test/CaseDetail.test.tsx`, `dashboard/test/ChwList.test.tsx`.

### Person 5: admin, design system and member management

You can demo: approving a reset; adding, switching off and deleting a member; a health centre's page; the Members
tabs on the web; and any screen looking right (theme, widgets, tab bars).

- **App:** `lib/core/theme/`, `lib/core/widgets/` (cards, buttons, avatars, pills, the tab bars),
  `lib/core/api/`, `lib/presentation/admin/` (resets, new account, centres), `lib/presentation/shell/` (the CHW
  tabs and the supervisor and admin shells).
- **Web:** `dashboard/components/admin/` (`ResetRequests`, `Members`, `MemberDetail`, `NewAccount`, `Centres`,
  `CentreDetail`), `dashboard/app/admin/`, `dashboard/lib/admin.ts`.
- **Server:** `server/src/admin/routes.ts` (members, deactivate, delete, centres, resets).
- **Tests:** `test/layout_test.dart` (every screen at four sizes), the admin cases in
  `test/presentation/role_screens_test.dart`, `server/test/admin.test.ts`, `dashboard/test/MemberDetail.test.tsx`.

### Where slices meet

These files are used by more than one person. The owner decides; the others ask or open a pull request.

| Shared thing | Owner | Who else touches it, and how |
| --- | --- | --- |
| Theme and shared widgets (`lib/core/theme`, `lib/core/widgets`) | 5 | Everyone uses them. Need a new widget? Build it in your own folder, then offer it to 5. |
| Local database tables (`lib/data/db.dart`) | 2 | Person 3 adds outbox and dispatch tables. Change it in a pull request reviewed by 2, then run `dart run build_runner build`. On a merge conflict in `db.g.dart`, regenerate it. |
| Router list (`server/src/app.ts`) | 1 | Each person adds one line for their router. |
| Dashboard shared types (`dashboard/lib/types.ts`) and sidebar links (`NavLinks.tsx`) | 1 | Each person adds the types and the link for their pages. |
| Test helpers (`server/test/emulator.ts`, `dashboard/test/helpers.ts`) | 1 | Add helpers; do not change existing ones. |
| Supervisor API (`server/src/supervisor/routes.ts`) | 4 | Person 3's inbox (`/alerts`) and person 2's Patients pages (`/patients`) read it. A change to a response needs a note to them. |
| Firestore rules (`firestore.rules`) | 2 | Person 3 asks 2 when alerts or SMS need a new field; deploy with `firebase deploy --only firestore`. |
| `test/widget_test.dart`, `test/presentation/role_screens_test.dart` | 2 and 4/5 | One file, split by test name: each person edits only their own cases. |
| This file and `README.md` | all | Each person keeps their own slice's section true. |

### Working rules

- One branch per person per task, named `feat/<slice>-<what>`, off the latest `main`; one other person reviews.
- Before opening a pull request, run your slice's tests: `flutter test <your test files>`, `cd server && npm test`
  (needs Java 21 for the emulators), `cd dashboard && npm test` and `npm run typecheck`; and `flutter analyze`.
- Every person submits **both** app and web code. A pull request that touches only one of the two is fine, but
  over a sprint each person's merged work must include both.

## State of the project

Built and tested: sign-in, offline records, sync, urgent alert by internet, supervisor inbox and case actions,
admin account and reset flows, the v3 redesign on the app and both dashboards, CHW and patient history, and
member management. Tests: Flutter, server (on the emulators) and dashboard suites all pass. The newest screens
(history, members, stat cards, redesign) have been checked by tests and, for the supervisor dashboard, in a
browser; most have not yet been tried on a phone, and the admin web pages have not been opened with a real admin
account. The offline SMS alert on the Firebase build, background sync and a live Africa's Talking number are
still to be tested. Clinical content (danger signs, ranges) is a placeholder until a clinician confirms it.

# HealthBridge Rwanda — Implementation Plan

Oct 6, 2026 · @GATETE Derrick

The riskiest parts, the SMS round-trip and the offline outbox, are built in sprints 2 and 3, before the full app screens, so the feature that makes HealthBridge different is proven early. The plan uses 8 one-week sprints; stretch or compress them to the course deadline.

## 1. Development ownership

Each member owns one slice of the system end to end, including its tests, so no one waits on another person's half-finished layer.

| Member | Area | Development tasks |
| --- | --- | --- |
| Gatete Derrick | Backend core and DevOps | Monorepo and GitHub Actions CI, including the release job that builds both flavours; Express + TypeScript setup; Prisma schema, migrations and seed data; auth (login, refresh, argon2id, JWT, role middleware); device registration and key issue; hosting on Render/Railway; API tests (Jest + Supertest) |
| Fabrice Mbarushimana | SMS pipeline | Payload codec and AES-GCM in TypeScript and Dart with shared test vectors; /webhooks/sms parsing, replay protection, two-part reassembly; acknowledgement SMS and delivery reports via Africa's Talking; `UrgentSender` (composer and direct send) and the store/managed Flutter flavours |
| Cedric Bigwi Hindura | Offline data and sync | drift schema with SQLCipher; repositories and Riverpod providers; outbox; workmanager background sync with back-off; reachability check; /sync/push and /sync/pull endpoints and conflict rules; draft autosave; danger-sign rule logic |
| Habibullah Ayodele | CHW app screens | Theme and reusable widgets; Login/PIN, Home, Patients (list, register, profile), Record visit stepper with the four forms and validation, Danger signs, Urgent screens, Alerts tab; Kinyarwanda and English (ARB files); widget tests |
| Melissa Isimbi | Supervisor dashboard | Next.js + Tailwind setup; supervisor login; alert inbox with 10 s polling; case detail; status actions; CHW list; the supervisor endpoints (GET/PATCH /alerts, GET /chws); dashboard tests (Vitest); end-to-end test script across app, API and dashboard |

Shared rules: every pull request is reviewed by one other member, and the owners of the two sides of an interface (for example Cedric's /sync endpoints and Habibullah's screens) agree its contract in the first sprint.

## 2. Sprints

| Sprint | Development goal | Deliverables (owner) | Done when |
| --- | --- | --- | --- |
| 1 | Foundations | Monorepo, CI, Express skeleton, Prisma schema + seed, auth endpoints (Derrick); Flutter skeleton with flavours and routing, plus the eight foundation widgets from the Design Brief (header, buttons, input field, status chip, summary card, patient card, bottom navigation) (Habibullah); drift schema (Cedric); Next.js skeleton (Melissa); codec spec and test vectors (Fabrice) | All three apps build in CI; login works against the deployed API |
| 2 | SMS round-trip | Codec + AES-GCM in TS and Dart, /webhooks/sms, ack SMS in sandbox (Fabrice); device registration (Derrick) | A simulator SMS becomes an alert row and an ack SMS goes back |
| 3 | Offline sync engine | Outbox, workmanager, reachability, /sync/push and /sync/pull (Cedric); API tests for sync (Derrick) | 20 visits recorded offline sync exactly once after a reboot |
| 4 | CHW core features | Login/PIN, Home, Patients, Record visit with four forms (Habibullah); repositories and drafts wired to screens (Cedric) | A routine visit goes from phone to database on a real device |
| 5 | Urgent flow | Danger signs and urgent screens (Habibullah); rule logic (Cedric); `UrgentSender` both flavours, ack reading, not-confirmed branch (Fabrice) | An urgent alert in airplane mode with a SIM reaches the database and is confirmed |
| 6 | Supervisor dashboard | Inbox, case detail, actions, CHW list, supervisor endpoints (Melissa); status pull to the CHW app (Cedric) | A supervisor resolves an SMS alert and the CHW sees it after sync |
| 7 | Localization and test suite | Kinyarwanda strings (Habibullah); end-to-end script (Melissa); integration tests for sync and SMS (Cedric, Fabrice); bug fixes (all) | All tests green in CI; every screen works in both languages |
| 8 | Release | Production deploy and environment config (Derrick); release job producing the Play .aab (store) and the managed .apk from one commit (Derrick); manifest check that only the managed build has SMS permissions (Fabrice); demo seed data (Cedric); dashboard production build (Melissa) | A clean install of each build on a new phone runs the full routine and urgent flows; the managed build sends the SMS with no tap |

## 3. Development risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Play Store blocks automatic SMS | Certain | High | Managed build (own app ID, APK installed by the health programme via sideload or MDM) sends directly and is used for the demo; the store build on Google Play uses the pre-filled composer |
| Africa's Talking live sender number takes weeks | Medium | Medium | Build and test on the sandbox simulator; one real-number test only |
| Dart and TypeScript encryption disagree | Medium | High | Shared test vectors checked in CI from sprint 2 |
| Four stacks for five people | High | Medium | If sprint 6 slips, rebuild the dashboard in Flutter Web with Habibullah's widgets |
| Background sync killed by phone battery savers | Medium | Medium | Also sync on app resume and connectivity change; tested on a low-end phone |
| SEND\_SMS leaks into the main manifest and Play rejects the upload | Medium | High | Permissions live only in the managed manifest; CI fails the store build if SEND\_SMS appears |
| A phone gets the wrong build, or the managed APK will not install | Medium | Low | Profile screen shows the build type; separate app IDs avoid signature clashes; installers allow unknown sources once |

## 4. Definition of done (every feature)

- [ ] Works with airplane mode on
- [ ] Status labels match the design brief
- [ ] English and Kinyarwanda strings present
- [ ] Unit tests for logic and one widget or integration test for the flow
- [ ] Passing in CI
- [ ] Reviewed by one other member in a pull request

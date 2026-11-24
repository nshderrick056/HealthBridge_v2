# HealthBridge Rwanda — App Flow Document

> **Updated Nov 2026** to match the built app: three sign-in methods, the redesigned Home and Profile, the three-step record flow, and the supervisor and admin screens. The urgent-case and sync flows are unchanged.


Oct 6, 2026 · @GATETE Derrick

The CHW app has five bottom tabs (Home, Patients, Record, Alerts, Profile); sync status lives on Home and on each record rather than in its own tab. Supervisors and admins have their own tabs in the app and a web dashboard; the supervisor's work is built around an alert inbox.

## 1. CHW screen map

| Tab | Screens | Notes |
| --- | --- | --- |
| (Entry) | Sign-in (PIN, SMS code or email + password), Forgot PIN or password, Choose your own PIN | An admin creates the account; the first sign-in uses a temporary PIN that must be replaced; later sign-ins work offline |
| Home | Stat cards (visited today, due for a visit, urgent today), urgent-case card, due-today cards, visited-today list, connection pill | The pill opens the Sync status screen |
| Patients | Patient list (All, Follow-up due, Urgent), Register patient, Patient profile, Visit history | Search works offline |
| Record | Step 1 Who is this visit for, Step 2 Record visit (visit type, danger signs, measurements, notes), Step 3 Review | Centre button, always one tap away |
| Alerts | Urgent cases sent, Follow-ups due | Shows each alert's delivery state |
| Profile | Name and role, Sync status, Settings (text size, default visit type, remember my phone number), Log out | Another CHW can sign in on the phone only after everything has uploaded |

## 2. Flow A: record a routine visit

1. Tap Record.
2. Search the patient, or Register new (name, sex, age or date of birth, village, consent tick).
3. Step 2: pick the visit type (Maternal, Child health, Malaria, Nutrition); the default type comes from Settings.
4. Fill the form: checkboxes and number steppers first, free text last and optional.
5. Danger signs are on the same screen: none ticked, tap Review visit.
6. Review, tap Save.
7. Confirmation "Saved on phone"; it changes to "Synced" when online or shows "Waiting to sync" when offline.

## 3. Flow B: urgent case

&#91;embedded content: Urgent case flow · internet, then SMS, then a call\]

1. Steps 1 to 4 as Flow A.
2. Danger-sign step: one or more ticked (for example heavy bleeding, convulsions, MUAC red).
3. Urgent screen: red banner, the ticked signs, one button: Send urgent alert.
4. The app tries the internet for up to 10 s, showing "Sending…".
5. Success: "Alert received by health centre" with the time.
6. Failure: "No internet. Sending by SMS." Store build (Google Play): the SMS app opens pre-filled and the CHW taps Send. Managed build (APK installed by the health programme): sent automatically, no tap.
7. Status "Sent by SMS, waiting for confirmation"; it becomes "Received" when the acknowledgement SMS arrives (read automatically in the managed build; in the store build the CHW sees it in her inbox and taps "I got the confirmation", or it updates on the next sync).
8. No confirmation after 10 min: "Not confirmed" with Resend and Call supervisor.
9. No mobile network at all: the app says so and shows Call supervisor.

## 4. Flow C: sync

1. Triggered by connectivity returning, app resume, or the 30-minute timer.
2. Outbox uploads in order; each record moves from Waiting to sync to Synced.
3. Failures stay listed as "Sync failed, tap to retry" with the reason in plain words.
4. Supervisor status changes (Reviewed, Follow-up requested) come down and appear on the Alerts tab.

## 5. Supervisor screen map

| Section | Screens |
| --- | --- |
| Sign-in | Email + password on the web dashboard; PIN, SMS code or email in the app |
| Alerts (home) | Urgent alert inbox: New, Reviewed, Escalated, Follow-up, Resolved filters |
| Case detail | Patient short ID, CHW, village, visit type, danger signs, vitals, channel badge, event history |
| CHWs | CHW list with last sync time and pending count; CHW detail with their visit history |
| Patients | Patient list, a patient's profile and visit history, a visit's detail |

## 5b. Admin screen map

| Section | Screens |
| --- | --- |
| Sign-in | Email + password |
| Resets | Pending forgot-PIN requests, Approve (the one-time code is texted) |
| Members | CHWs and Supervisors tabs; a member's details with Deactivate and Delete |
| New account | Name, role, phone, email (optional), health centre; a temporary PIN or password is texted |
| Centres | List of health centres, add a centre, a centre's details |

## 6. Flow D: supervisor handles an alert

1. A new urgent alert appears at the top of the inbox within 10 s, with a channel badge (Internet / SMS) and time received.
2. Open the case: details from the SMS, or the full record if synced; "Full record pending" if only the SMS has arrived.
3. Choose an action: Mark reviewed, Escalate (referral to hospital), or Request follow-up (with a date).
4. The CHW gets the status on her next sync, or by SMS for Escalate and Follow-up.
5. Mark Resolved to close the case.

## 7. Edge cases

- App killed mid-form: the draft autosaves on every field change and reopens where the CHW left off.
- Same patient registered twice offline: the server flags a possible duplicate (name + date of birth + village) for the supervisor to merge. (Planned; not built yet.)
- Wrong phone clock: the server keeps both device time and received time; the dashboard sorts by received time.
- SMS split into two parts arriving out of order: the server reassembles by part header before decrypting.
- Tampered or unknown-device SMS: rejected, logged, no reply sent.
- CHW logs out with unsynced records: the records stay on the phone, and another CHW can sign in only after they have all uploaded.

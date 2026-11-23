# Demo tour: the app, the Firebase Console and the dashboards

The presenter's script for the live walkthrough: **the phone app and the Firebase Console are the main part (about 4 minutes), the dashboards a short extra (about 1 minute).** This is the 5-minute tour Person 4 gives at the start of the video (see [VIDEO_SCRIPTS.md](VIDEO_SCRIPTS.md)). It performs the 7 required actions from the assignment and shows each change in the Console as it happens.

No slide deck, no cuts, no introductions of the team. One continuous recording of the release APK on a physical phone.

## Time budget

| Time | Part | Emphasis |
|---|---|---|
| 0:00 to 0:25 | Cold start | app |
| 0:25 to 1:25 | Create the account, first sign-in, log out, log in | app + Console (users, Authentication) |
| 1:25 to 2:10 | Walk every screen, rotate once, validation message | app |
| 2:10 to 2:40 | One state change, two widgets | app |
| 2:40 to 3:40 | CRUD on a patient with the Console visible | **Console** + app |
| 3:40 to 4:10 | Change a setting, restart, still there | app |
| 4:10 to 4:50 | Dashboards | dashboards |
| 4:50 to 5:00 | Hand-off to the code | none |

## Set-up before pressing record

**Screen layout.** The recording must show the phone and the Console at the same time. Put the Console on the laptop, large, and hold the phone steady in front of the camera, or mirror the phone on the laptop beside the Console.

**Firebase Console tabs** (project `healthbridge-rwanda`), open in this order so you can switch with Ctrl+Tab:
1. Firestore Database, collection `users`
2. Firestore Database, collection `patients`
3. Firestore Database, collection `alerts` (and its `events` subcollection)
4. Authentication → Users
5. Firestore → Rules (optional, for the rules question)

**Services running:** the API on port 3000, the dashboard on port 3001, and the tunnel. The phone app must be built with the tunnel's current address, or sign-in fails.

**Africa's Talking simulator:** open the sandbox simulator on the new account's phone number *before* creating the account. The temporary PIN text appears there, not on a real phone, because the server runs in sandbox mode.

**Accounts ready:** an admin (email and password), a supervisor, and the phone number you will use for the new health worker.

**Keep off camera:** the Console collections `credentials` and `deviceKeys` (they hold PIN hashes and keys), and the temporary PIN if you can avoid it.

---

## 1. Cold start (0:00 to 0:25), app

**Do:** the app is fully closed (swipe it away). Open it from the launcher. It lands on sign-in.

**Say:** "This is HealthBridge, an offline-first app for community health workers in Rwanda. The app was fully closed, so this is a **cold start**. On startup it tried to restore the saved Firebase session, found none, and shows sign-in. There are three ways to sign in: PIN, SMS code and email with a password."

## 2. Create the account and sign in (0:25 to 1:25), app + Console

**Do (laptop):** on the admin dashboard open **Members → New account**. Fill in name, role CHW, the simulator phone number and the health centre. Submit.

**Say:** "Accounts are not self-registered, because health data needs a trusted person to create them. So **registration is done by an admin**, here on the dashboard."

**Do (Console, tab 1 `users`):** the new document is there. Point at `role`, `healthCenterId`, `phone`, `active: true`. Then tab 4, **Authentication → Users**: the same person appears.

**Say:** "In the Console, a new document in `users`, with the role, the health centre and `active` true. And in Authentication, the same account. The server also made a random temporary PIN and texted it, and it never appears on the admin screen."

**Do (simulator):** show the text with the temporary PIN for a second, then close it.

**Do (phone):** choose **PIN**. First type a three-digit PIN and press Sign in: the form shows a polite message and sends nothing. Then enter the real temporary PIN. The app asks for your own PIN: enter two different ones, show the "PINs differ" message, then two matching ones.

**Say:** "A wrong-format PIN is stopped by the form's `validator` with a clear message, before anything is sent. With the right temporary PIN, the `mc` claim in my token makes the app show **choose my own PIN** before anything else. Different entries are rejected; matching ones are accepted."

**Do (phone):** open Profile and **log out**. Back on sign-in, choose **Email** and log in with an email and password (use an account that has them, for example the supervisor).

**Say:** "Now I log out, and log in a second way, with email and password. Both methods lead to the same signed-in session."

## 3. Every screen, rotate once (1:25 to 2:10), app

**Do (CHW account):** go through each screen, about 5 seconds each: Home (stat cards: Visited today, Due for a visit, Urgent today), Patients (type in search), a patient profile with its history, Record a visit, Sync status, Settings. Rotate the phone once to landscape on Home, then back.

**Say:** "This is the health worker's app. Home shows stat cards fed by Riverpod providers: visited today, due for a visit, urgent today. Patients has search. Each patient has a profile with their visit history. Here is the visit form and the sync status, which shows what is still waiting to upload. And Settings. If I rotate to landscape, there are no `RenderFlex` overflows."

**Do:** in the visit form enter a temperature of 99.

**Say:** "A second validation message: 99 degrees is rejected with 'Enter 30.0 to 45.0 °C'. The allowed ranges live in one file."

## 4. One state change, two widgets (2:10 to 2:40), app

**Do:** on a new visit tick a danger sign and tap **Send urgent alert**. Go to Home.

**Say:** "Now **one state change updating two widgets**. I add a danger sign and send the alert. The Urgent-today stat card goes up and the red alert card appears. They both `ref.watch` the same `StreamProvider`, so they rebuild together with no `setState`."

**Console (tab 3 `alerts`):** the new alert appears with `status: new`, `channel: internet`.

**Say:** "And in the Console, the alert arrived, with status new, sent over the internet."

## 5. CRUD with the Console visible (2:40 to 3:40), Console + app

This is the most important part. Keep the phone and the `patients` collection (tab 2) in view together.

| Step | Do on the phone | What the Console shows |
|---|---|---|
| Create | Patients → New patient: name, village, sex, age, consent, Save | a new document appears in `patients` with `fullName`, `village`, `shortId`, `chwId`, `healthCenterId`, `createdAt` |
| Read | open the patient's profile | (the app reads its own local copy; point at the same fields in the Console) |
| Update | edit the village, Save | the same document's `village` and `updatedAt` change |
| Delete | archive the patient | the document stays and gets `archivedAt` (Firestore never deletes it) |

**Say:** "Now **create, read, update and delete**, with the Console beside the phone. **Create:** I register a patient. The app writes to the local drift database first, so it works offline, then the sync engine uploads it. There it is in the Console, with the field names from our diagram. **Read:** here is the profile and history. **Update:** I change the village, and the Console shows the new village and update time. **Delete:** I archive the patient. The document does **not** disappear: it gets an `archivedAt` field, because our security rules forbid deleting health records. The app hides it everywhere, but the record is kept."

**If the Console is slow:** keep talking for a few seconds ("the upload runs in the background") and press the Console's refresh. If it still does not appear, open Sync status on the phone and show "all sent".

**Optional 10 seconds (rules question):** open the **Rules** tab and point at `allow delete: if false` under `patients`.

## 6. A preference that survives a restart (3:40 to 4:10), app

**Do:** Settings: text size **Large**, default visit type **Child**, **Remember login** on. Swipe the app away and reopen it.

**Say:** "In Settings I change the text size, the default visit type, and turn remember login on. Now I close the app completely and reopen it. All three are still set, and the phone number is filled in. They are saved with `SharedPreferences` through a Riverpod `Notifier`, and the PIN is never saved."

## 7. The dashboards (4:10 to 4:50), dashboards

**Do (laptop, about 20 seconds each):**
- **Supervisor dashboard:** the alert inbox, open the new case, add a note, press **Escalate**. Then in the Console tab 3 open the `alerts` document: `status` is now `escalated`, and the `events` subcollection has a new record (who, from, to, note).
- **Admin dashboard:** Members with the CHW and Supervisor tabs, open the new member, show **Deactivate**. Then in the Console, Authentication: after deactivating, the account shows as disabled.

**Say:** "The same system has two web dashboards. A supervisor sees their centre's alerts, and a case can be escalated with a note. The Console shows the status changed and an event was written. An admin manages members: here are the CHW and Supervisor tabs, and deactivate, which also disables the account in Authentication, so that person is locked out at once."

**Only deactivate a test account.** If you do it live, reactivate it afterwards.

## 8. Hand-off (4:50 to 5:00)

**Say:** "That is how it works. Now the team explains the code behind it. First, [Name]."

---

## Console cheat sheet: what to point at

| Where | Collection | Fields to point at | Shows |
|---|---|---|---|
| Firestore | `users` | `role`, `healthCenterId`, `phone`, `active`, `createdAt` | the account the admin created |
| Firestore | `patients` | `fullName`, `village`, `shortId`, `chwId`, `healthCenterId`, `updatedAt`, `archivedAt` | create, update and archive from the phone |
| Firestore | `visits` | `type`, `isUrgent`, `dangerSigns`, `source` (`app`) | the urgent visit; `isUrgent` is true exactly when there are danger signs |
| Firestore | `alerts` | `status`, `channel`, `chwId`, `healthCenterId` | the urgent alert; status changes from the dashboard |
| Firestore | `alerts/{id}/events` | `actorId`, `fromStatus`, `toStatus`, `note`, `createdAt` | the history of status changes |
| Authentication | Users | the account, and "Disabled" after deactivate | the sign-in account |
| Firestore | Rules tab | `allow delete: if false` under `patients` | why delete is an archive |

**Not to show on camera:** `credentials` (PIN hashes), `deviceKeys` (SMS keys), `resetRequests`.

## If something goes wrong

| Problem | Do this |
|---|---|
| The temporary PIN text does not appear | The simulator was not open on that number first. Open it and create another account. |
| Sign-in says wrong phone or PIN | Check the PIN. Five wrong tries lock the account for 15 minutes. |
| The app cannot reach the server | The tunnel address changed. Rebuild the app with the new address. |
| The Console does not show the new document | Refresh the Console; check Sync status on the phone for items still waiting. |
| Offline SMS alert fails | Not part of this tour; skip it. |

## If you run long

Drop, in this order: the Optional Rules tab pointer, the admin dashboard part, the landscape rotation sentence, the second login method.

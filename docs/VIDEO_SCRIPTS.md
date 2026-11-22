# Video demo scripts (15 minutes, five people)

One continuous recording, 1080p, no cuts, no speed-ups, no slide deck, no team introductions. The release APK runs on a physical phone. The assignment also asks that every member presents an aspect, and that the video shows both sign-in methods, CRUD with the Firebase Console visible, and the app on a real device.

## Structure

| Time | Who | What |
|---|---|---|
| 0:00 to 5:00 | **Person 4, the guide** | How the app and both dashboards work. Performs all 7 required actions. |
| 5:00 to 7:00 | Person 1 | Code: authentication, SharedPreferences, why Riverpod |
| 7:00 to 9:00 | Person 2 | Code: Firestore CRUD, ERD to Firestore, security rules |
| 9:00 to 11:00 | Person 3 | Code: urgent alerts, sync, the shared-state update |
| 11:00 to 13:00 | Person 4 | Code: clean architecture, supervisor case flow |
| 13:00 to 14:45 | Person 5 | Code: design system, layout and tests, GitHub history |
| 14:45 to 15:00 | Person 5 | One-line close |

The guide (Person 4) speaks twice: the 5-minute tour, then their own 2 minutes of code. The other four speak once, for 2 minutes. If you run short or long, the "cut first" list at the bottom says what to drop.

**How code is shown without a slide deck:** keep the laptop on the same table. Each person opens the named file in the editor (large font) and points the phone camera or a second camera at the screen, or the recording captures the laptop screen. Say the file name and the term aloud. If the lecturer does not allow showing code at all, speak the same script from the "say" lines and keep the snippets for the report.

## The 7 required actions (all inside the guide's 5 minutes)

| # | Action | Where in the tour |
|---|---|---|
| 1 | Cold-start launch | 0:00 |
| 2 | Register, log out, log in | 0:25 to 1:20 |
| 3 | Visit every screen and rotate once | 1:20 to 2:20 |
| 4 | Create, read, update, delete in Firestore with the Console visible | 2:50 to 3:30 |
| 5 | A state update touching two widgets | 2:20 to 2:50 |
| 6 | Change a SharedPreferences setting, restart, show it persisted | 3:30 to 4:00 |
| 7 | Force a validation error with a polite message | 0:45 and 1:50 |

## Before recording (everyone)

- Release APK installed, Wi-Fi on. Firebase Console open on the laptop on the `patients` and `users` collections. Dashboard open on the laptop.
- Prepared accounts: one admin, one supervisor (email and password), one **new** CHW created minutes before the take whose temporary PIN you can read (Africa's Talking sandbox simulator).
- Run `flutter analyze` and `flutter test --coverage` the day before. **Say the real numbers.** Do not say "70 percent" unless the report shows it.
- Rehearse Person 3's offline SMS path. It was not phone-tested on the Firebase build. If it fails, show the online path and say the SMS codec is covered by shared test vectors.
- Keep PINs, passwords and keys off the camera.

---

# Part 1: the guide, how the app and dashboards work (Person 4, 0:00 to 5:00)

Speak calmly; about 600 words fits in 5 minutes. Do not introduce anyone.

> **(0:00, cold start)** "This is HealthBridge, an offline-first app for community health workers in Rwanda, with web dashboards for supervisors and admins. The app is closed. [open it] That is a **cold start**. It finds no session and shows sign-in."
>
> **(0:20, register)** "Accounts are not self-registered, because health data needs a trusted person to create them. So **registration happens on the admin dashboard**. [laptop] The admin opens Members, New account, and creates a health worker. [Console] The `users` document appears here. The server texts a temporary PIN."
>
> **(0:45, sign in)** "On the phone there are **three ways to sign in**: PIN, SMS code, and email with a password. I use the temporary PIN. First a mistake: a three-digit PIN. [show] The form says what is wrong, politely, and sends nothing. Now the right PIN. The app forces me to **choose my own PIN**. [mismatch, then match] Now I **log out**, and **log in** a second way, with email and password. Both methods give the same session."
>
> **(1:20, every screen)** "This is the health worker's app. Home has **stat cards**: visited today, due, urgent. [tap each tab] Patients, with search. A patient profile with visit history. Record a visit. Sync status. Settings. [rotate once] In landscape nothing overflows."
>
> **(1:50, validation)** "In the visit form I enter a temperature of 99. [show] It says 'Enter 30.0 to 45.0 °C'. Polite, and the range lives in one file."
>
> **(2:20, two widgets)** "Now **one state change updating two widgets**. I add a danger sign and send the alert. [point] The Urgent-today stat card and the red alert card both change, because they read the same Riverpod provider."
>
> **(2:50, CRUD with the Console)** "Now **CRUD with the Console visible**. I create a patient: [Console] the document appears. I read it in the profile. I edit the village: [Console] it updates. I delete: the app archives it, the document stays with an `archivedAt` field, because the rules forbid hard deletes on health records."
>
> **(3:30, SharedPreferences)** "In Settings I set text size to Large, default visit type to Child, and turn Remember login on. [kill app, reopen] All three are still there."
>
> **(4:00, dashboards)** "On the **supervisor dashboard**: the alert inbox, a case, Escalate with a note, the CHW list, a CHW's visit history, a patient's profile and history. On the **admin dashboard**: Members with CHW and Supervisor tabs, a member's details with Deactivate and Delete, and Centres with details. They share the same server and rules as the app."
>
> **(4:50)** "Now the team explains the code behind this. First [Person 1]."

**Cut first if short on time:** the landscape explanation, the centre details, the Forgot-PIN mention.

---

# Part 2: the code, five people, about 2 minutes each

Each person says **one assignment question** ("be prepared to explain") plus their best code. Keep to the clock.

## Person 1 (5:00 to 7:00): authentication, SharedPreferences, why Riverpod

**Assignment question:** why this state management is appropriate.

> "I did authentication and local preferences. We chose **Riverpod** because state is compile-checked, testable without a `BuildContext`, and rebuilds only the widgets that watch it. We use no `setState`."
>
> "[login_controller.dart] Sign-in is one `Notifier`, `LoginController`, with three methods: PIN, SMS code, email. Validators like `validatePin` run in the form, so the screen has no logic. Success sets the session provider and the root widget swaps the screen."
>
> "[server auth/routes.ts] The PIN goes to our server, which checks an **Argon2 hash**, counts failures, and **locks the account for 15 minutes after five**. Then it returns a **Firebase custom token** with **custom claims**: role, health centre, and a must-change flag, which is why a new account is forced to choose its own PIN. Forgot PIN uses an **OTP**: 30 minutes, five tries."
>
> "[settings.dart] **SharedPreferences**: three preferences, restored in `build()` and saved on every change, which is why they survived the restart."

Snippets (keep on screen or in the report):

```dart
@override
AppSettings build() {
  final p = ref.watch(sharedPreferencesProvider);
  return AppSettings(
    textSize: TextSize.values.asNameMap()[p.getString(_textSize)] ?? TextSize.normal,
    defaultVisitType: VisitType.values.asNameMap()[p.getString(_visitType)] ?? VisitType.maternal,
    rememberLogin: p.getBool(_remember) ?? false,
  );
}
Future<void> setTextSize(TextSize size) async {
  state = _with(textSize: size);                // UI updates at once
  await _prefs.setString(_textSize, size.name); // then saved
}
```

```ts
if (!(await verify(cred.pinHash, given))) {
  const locks = (cred.failedLogins ?? 0) + 1 >= MAX_FAILED_LOGINS;
  await credRef.update(locks
    ? { failedLogins: 0, lockedUntil: Timestamp.fromMillis(Date.now() + LOCK_MS) }
    : { failedLogins: FieldValue.increment(1) });
  throw unauthorized();
}
res.json({ customToken: await fb.auth.createCustomToken(user.id, { role: user.role, hc: user.healthCenterId }) });
```

Terms: custom token, custom claims, Argon2, lockout, OTP, `Notifier`, `ref.watch`, persisted preferences.

## Person 2 (7:00 to 9:00): Firestore CRUD, ERD to Firestore, security rules

**Assignment questions:** how the ERD matches the database; how the rules protect data.

> "I did patients, visits and the data model. Our ERD in `docs/ERD.md` has `users`, `healthCenters`, `patients`, `visits` and `alerts`. The Firestore collections match it field for field, in camelCase. A visit stores only `patientId`, never the patient's data, so nothing is duplicated."
>
> "[patients_repository.dart] **Create** writes the patient to the encrypted local database, **drift on SQLCipher**, and an **outbox** row in the same transaction. A record can never be saved without being queued. Sync uploads it, which is what you saw appear in the Console. **Read** is a drift stream, so the list updates live. **Update** re-queues. **Delete** is `archive`: it sets `archivedAt`."
>
> "[firestore.rules] Why archive: the rules say `allow delete: if false`. A CHW reads and writes only their own patients; a supervisor reads only their centre's; `chwId`, `healthCenterId`, `shortId` and `createdAt` cannot change after creation; and a visit's `isUrgent` must equal `dangerSigns.size() > 0`, so a client cannot fake urgency. Indexes are in `firestore.indexes.json`."

Snippets:

```dart
return _db.transaction(() async {
  final patient = await _db.into(_db.patients).insertReturning(row);
  await _enqueue(patient);      // outbox row, same transaction
  return patient;
});
Future<Patient> archive(Patient p) => update(p.copyWith(archivedAt: Value(_now())));
```

```
match /patients/{patientId} {
  allow read: if (isChw() && existing().chwId == uid())
    || (isSupervisor() && existing().healthCenterId == hc());
  allow create: if isChw() && validPatient()
    && incoming().chwId == uid() && incoming().healthCenterId == hc();
  allow update: if isChw() && existing().chwId == uid() && validPatient()
    && same('chwId') && same('healthCenterId') && same('shortId') && same('createdAt');
  allow delete: if false;
}
```

Terms: offline-first, SQLCipher, transaction, outbox, soft delete, `hasOnly`, owner-limited rules, composite index.

## Person 3 (9:00 to 11:00): urgent alerts, sync and shared state

**Assignment question:** state management in action across components.

> "I did urgent alerts and sync. The Home alert card and the stat card you saw both read one provider, `allDispatchesProvider`, a **StreamProvider** over the local database. When the dispatch state changes, both widgets rebuild from **one source of truth**. The connection pill reads `isOnlineProvider`."
>
> "[urgent_dispatcher.dart] `send` tries the internet with a **10-second timeout**. If that fails it falls back to SMS. [codec.dart] The SMS is encrypted with **AES-256-GCM**, with the header as **associated data**, so a message cannot be replayed under another device. The server decrypts it, makes a partial case, and replies with an **HMAC-signed** `HB OK` code. The app ignores acknowledgements whose tag does not match, so only our server can confirm. After 10 minutes with no ack, the card offers Resend and Call."
>
> "When the phone is back online the full visit uploads and **merges into the same case**. The **sync engine** drains the outbox; **workmanager** runs it in the background."

Snippets:

```dart
Future<void> send(String visitId) async {
  await _repo.start(visitId);
  try {
    await _postAlert(visitId).timeout(internetTimeout);   // 10 s
    await _repo.updateState(visitId, DispatchState.confirmed);
  } on Exception {
    await sendSms(visitId);
  }
}
if (parts[1] != await ackTag(device.smsKey, parts[0])) continue; // not from our server
```

Terms: `StreamProvider`, single source of truth, AES-GCM, associated data, HMAC, idempotent merge, outbox, workmanager. Shared test vectors keep the Dart and TypeScript codecs byte-identical.

## Person 4 (11:00 to 13:00): clean architecture and the supervisor case flow

**Assignment question:** how the code follows clean architecture.

> "Now the code. Our app is in three layers under `lib/`. **Presentation** holds screens, each with a Riverpod controller beside it. **Domain** holds entities, repository interfaces and use cases. **Data** holds the drift database and repositories that implement those interfaces. Screens never talk to Firebase or the database directly; the repository pattern keeps logic out of UI files."
>
> "[case_screen.dart] The case screen only collects input and shows a snackbar. The work is in `CaseStatusController`: it calls the server, then `ref.invalidate`s the case and the inbox so the UI refreshes at once, and any error comes back as a snackbar message."
>
> "[server supervisor/routes.ts] The status change is a **state machine**, `TRANSITIONS`. The server re-reads the status inside a Firestore **transaction**, rejects an illegal move, and writes an event to a subcollection, so two supervisors cannot overwrite each other and every change has an author. All supervisor queries are **scoped by health centre on the server**; another centre's CHW returns 404."

Snippets:

```dart
Future<void> _move(AlertStatus to) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await ref.read(caseStatusProvider(widget.alertId).notifier).move(to, _note.text);
  if (error == null) _note.clear();
  messenger.showSnackBar(SnackBar(content: Text(error ?? 'Case moved to ${to.label}')));
}
```

```ts
const TRANSITIONS: Record<AlertStatus, AlertStatus[]> = {
  new: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  reviewed: ['escalated', 'follow_up', 'resolved'],
  escalated: ['follow_up', 'resolved'],
  follow_up: ['escalated', 'resolved'],
  resolved: [],
};
```

Terms: presentation, domain, data, repository interface, `FutureProvider.family`, `ref.invalidate`, role-based shell with `IndexedStack`, Firestore transaction, tenant scoping.

## Person 5 (13:00 to 14:45): design system, layout tests, quality and GitHub history

**Assignment questions:** how testing validates the app; how GitHub history shows collaboration.

> "I did the design system, the admin screens and testing. [widgets.dart] Every screen uses one set of widgets: `HbButton`, a 56-pixel pill; `HbCard`, 24-pixel corners; chips, avatars, a floating tab bar. Colours are tokens in `HbColors`, with contrast measured: 4.9 to 1 on brand green, 5 to 1 on red, above the 4.5 requirement, and tap targets at least 48 pixels."
>
> "[layout_test.dart] To prove it works on small and large phones and in landscape, a **widget test** renders every main screen at four sizes: 320 by 568, 430 by 932, landscape, and landscape with extra-large text. Any `RenderFlex` overflow fails the test."
>
> "[terminal] `flutter analyze` reports [say the real result]. `flutter test` runs [say the real number] tests, with [say the real number] percent coverage; the server has its own tests on the Firebase emulators, and the dashboard has its own."
>
> "[terminal, `git shortlog -sn`] Our history shows every member's commits and branches over the weeks, and the contribution tracker matches it. On the admin side, deactivating a member disables the Auth user and revokes their tokens, so they are locked out at once. Thank you for watching."

Snippets:

```dart
const _sizes = {
  'small phone (320x568)': (Size(320, 568), 0.55),
  'large phone (430x932)': (Size(430, 932), 0.55),
  'landscape (844x390)': (Size(844, 390), 0.55),
  'landscape, extra large text': (Size(844, 390), 0.72),
};
```

```ts
await fb.auth.updateUser(id, { disabled: !active });
if (!active) await fb.auth.revokeRefreshTokens(id);
await users.doc(id).update({ active });
```

Terms: design tokens, Material theme, WCAG contrast 4.5:1, tap target, `RenderFlex`, widget test, unit test, coverage, `ProviderScope` overrides.

---

## Hand-offs (one sentence)

- Guide to 1: "Now [Name] explains how sign-in and preferences are built."
- 1 to 2: "Accounts and settings are covered; [Name] shows the data side."
- 2 to 3: "Data is stored; [Name] shows how alerts and shared state work."
- 3 to 4: "The alert has left the phone; [Name] shows how the code is organised and what the supervisor does."
- 4 to 5: "[Name] closes with the design system and the tests."

## Cut first if you run over

Guide: Forgot PIN, landscape sentence, centre details. Person 1: the lockout detail. Person 2: indexes. Person 3: Resend and Call. Person 4: tenant scoping. Person 5: the deactivate paragraph.

## Notes

- The dashboards are web pages. The assignment says a web build of the app gets zero, so show them only as a short extra (1 minute, guide only) alongside the phone, never instead of it.
- Registration here is an admin creating the account, followed by the first sign-in. Say that clearly so the "register" step is not mistaken for missing.
- No unverified numbers: coverage, analyze result and test counts are said from a run done on the day.

# Video demo: five 3-minute scripts

One continuous recording of the **release APK on a physical phone**, 1080p, no cuts, no speed-ups, no slide deck, no team introductions. Every member speaks, and each hand-off is one sentence. Total: 15 minutes (the limit is 10 to 15, so aim for 2:45 each and finish near 14).

The code snippets below are **speaker notes**, not slides. Say the file name and the technical term out loud; the rubric forbids a deck, so do not screen-share code unless the lecturer allows it. The same snippets go in the written report.

## The seven required actions, and who does them

| # | Required action | Person |
|---|---|---|
| 1 | Cold-start launch | 1 |
| 2 | Register, log out, log in | 1 |
| 3 | Visit every screen and rotate once | 4 (CHW and supervisor screens), 5 (admin screens and the rotation) |
| 4 | Create, read, update, delete in Firestore with the Firebase Console visible | 2 |
| 5 | A state update that touches two widgets | 3 |
| 6 | Change a SharedPreferences setting, restart, show it persisted | 1 |
| 7 | Force a validation error and show a polite message | 1 (login) and 2 (forms) |

## Before recording (everyone)

- Phone on release APK, Wi-Fi on, Firebase Console open on a laptop in view of the camera or on a split screen.
- One test admin, one supervisor, one CHW already created. Know the temporary PIN of the CHW you will "register".
- `flutter analyze` shows 0 issues and `flutter test` passes (129 tests) the day before; you will say it in one sentence each.
- **Rehearse Person 3's offline SMS path.** It was not phone-tested on the Firebase build. If it fails on the day, show the online path and the Sync screen instead, and say the SMS path is covered by the codec test vectors.
- Do not read passwords or PINs aloud and keep them off the camera.

---

## Person 1 (0:00 to 3:00): Authentication, sign-in and SharedPreferences

**Rubric items:** Authentication (5), SharedPreferences (5), action 1, 2, 6, 7. Also states: Riverpod (`Notifier`).

**On screen:** cold start from a killed app; sign-in screen with the three method chips; a wrong-format PIN; first sign-in with a temporary PIN; forced "choose your own PIN"; log out; log in; Settings; change text size, default visit type and Remember login; swipe the app away; relaunch.

### Script

> **(0:00)** "I am [name]. I did authentication and local preferences. I start with a **cold start**: the app is killed, and I open it now. [tap icon] The splash restores the session, finds nobody signed in, and shows the sign-in screen."
>
> **(0:20)** "There are **three authentication methods**: phone and PIN, an SMS one-time code, and email with a password. Accounts are not self-registered: an admin creates them and the server texts a **temporary PIN**. So here, 'register' means first sign-in. I type the phone number and the temporary PIN."
>
> **(0:40)** "First, a **validation error**. I type a three-digit PIN and press Sign in. [show] The form stops me with a polite message before anything is sent. This is `validatePin` in `login_controller.dart`; the form calls the validators, so there is no logic inside the widget."
>
> **(1:00)** "Now the correct temporary PIN. The app calls our server, which checks an **Argon2 hash** in a server-only collection, counts failed tries, and after **five failures locks the account for 15 minutes**. On success it mints a **Firebase custom token** with **custom claims**: role, health centre and a `mc` must-change flag. Because `mc` is set, the app shows **Choose your own PIN**. I type two different PINs, and it says they differ. Now matching ones. The server clears the flag."
>
> **(1:35)** "I **log out**, and **log in** again with my new PIN. There is also **Forgot PIN**: the admin approves the request and a **one-time code** with a 30-minute life and 5 tries is sent."
>
> **(1:55)** "State: sign-in is a Riverpod `Notifier`, `LoginController`. Success sets `sessionProvider`, and the root widget swaps the screen. No `setState` anywhere."
>
> **(2:10)** "Now **SharedPreferences**. In Settings I save three preferences: text size, default visit type, and Remember login. I set text size to Large, visit type to Child, and switch Remember login on. The screen rescales immediately because the setting is a provider. I now **kill the app** and relaunch. [do it] The text is still Large, the visit type is still Child, and the phone number is pre-filled. That is `SettingsController`, which reads the stored values in `build()` and writes on every change."
>
> **(2:40)** "Clean architecture: my screens are in `presentation/auth`, the Firebase calls are behind `AuthService` in `core/auth`. Tests: login controller tests and settings tests, all in the 129 passing. Over to [Person 2], who will do the Firestore part."

### Snippets to keep in the report and in your head

`lib/core/settings/settings.dart`, restore on launch, write on change:

```dart
class SettingsController extends Notifier<AppSettings> {
  static const _textSize = 'settings.textSize';
  static const _visitType = 'settings.defaultVisitType';
  static const _remember = 'settings.rememberLogin';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    final remember = p.getBool(_remember) ?? false;
    return AppSettings(
      textSize: TextSize.values.asNameMap()[p.getString(_textSize)] ?? TextSize.normal,
      defaultVisitType: VisitType.values.asNameMap()[p.getString(_visitType)] ?? VisitType.maternal,
      rememberLogin: remember,
      savedLoginId: remember ? p.getString('settings.loginId') : null,
    );
  }

  Future<void> setTextSize(TextSize size) async {
    state = _with(textSize: size);              // UI updates at once
    await _prefs.setString(_textSize, size.name); // then it is saved
  }
}
```

`lib/presentation/auth/login_controller.dart`, three methods, one controller:

```dart
enum LoginMethod { pin, smsCode, email }

Future<void> submit(String id, String secret) => _run(id, () =>
    state.method == LoginMethod.email
        ? _auth.signInWithEmail(id.trim(), secret)
        : _auth.signInWithPin(normalizePhone(id), secret));
```

`server/src/auth/routes.ts`, the lockout and the custom token:

```ts
if (!(await verify(cred.pinHash, given))) {
  const locks = (cred.failedLogins ?? 0) + 1 >= MAX_FAILED_LOGINS;
  await credRef.update(locks
    ? { failedLogins: 0, lockedUntil: Timestamp.fromMillis(Date.now() + LOCK_MS) }
    : { failedLogins: FieldValue.increment(1) });
  throw unauthorized();
}
const claims = { role: user.role, hc: user.healthCenterId };
res.json({ customToken: await fb.auth.createCustomToken(user.id, claims) });
```

**Terms to say:** Firebase Auth, custom token, custom claims, Argon2, lockout, OTP, `Notifier`, `SharedPreferences`, persisted session, validators.

---

## Person 2 (3:00 to 6:00): Patients and visits, Firestore CRUD, ERD and rules

**Rubric items:** CRUD (5), Database design ERD to Firestore (10), action 4, action 7 (second validation), Clean Architecture (5).

**On screen:** Patients tab with the Firebase Console `patients` collection visible beside it. Register a patient (create), open the profile (read), edit the village (update), archive (delete). Show each change appear in the Console within seconds. Then enter age "abc" and a temperature of 99.

### Script

> **(3:00)** "I am [name]. I did patients, visits and the data model. I will do **CRUD** with the **Firebase Console open** beside the phone. Here is the `patients` collection."
>
> **(3:20)** "**Create.** I register a patient: name, village, sex, age, and a consent tick. The app saves to the **local encrypted database**, drift on **SQLCipher**, so it works offline. In the same **transaction** it writes an **outbox** row, so a record is never saved without being queued. When the sync engine uploads it, [point to Console] the document appears here, with the same field names as our ERD."
>
> **(3:55)** "**Read.** The patients list is a **stream**: `watch()` returns a Drift stream, so the list is live and the search box filters name, short ID or village as I type. I open the profile to read the visit history."
>
> **(4:20)** "**Update.** I change the village. The UI updates at once, the row is marked queued, and the Console shows the new `updatedAt` and village a moment later."
>
> **(4:45)** "**Delete.** I archive the patient. Notice I do not hard-delete: our **Firestore rules** say `allow delete: if false`, because health records must be kept. 'Delete' sets `archivedAt`, the patient disappears from every list, and the document stays in the Console with that field. That is a deliberate, safe design."
>
> **(5:10)** "**Validation.** I enter the age as letters. [show] It says 'Enter the age in whole years (0 to 130)'. Then a temperature of 99: 'Enter 30.0 to 45.0 °C'. These ranges live in `NumberRange` in `validation.dart` and nowhere else. Errors from the repository appear as **snackbars**."
>
> **(5:30)** "**Database design.** Our ERD in `docs/ERD.md` maps to collections: `users`, `healthCenters`, `patients`, `visits`, `alerts`. Fields are camelCase everywhere. Patient data is not copied into visits; a visit holds only `patientId`. The rules are **owner-limited**: a CHW reads only their own patients, a supervisor reads their own centre's, and the visit rule checks that `isUrgent` equals `dangerSigns.size() > 0`. Over to [Person 3]."

### Snippets

`lib/data/repositories/patients_repository.dart`, create and outbox in one transaction; archive as an update:

```dart
return _db.transaction(() async {
  final patient = await _db.into(_db.patients).insertReturning(row);
  await _enqueue(patient);          // outbox row, same transaction
  return patient;
});

Future<Patient> archive(Patient p) =>
    update(p.copyWith(archivedAt: Value(_now())));
```

`firestore.rules`, owner-limited, immutable keys, no delete:

```
match /patients/{patientId} {
  allow read: if (isChw() && existing().chwId == uid())
    || (isSupervisor() && existing().healthCenterId == hc());
  allow create: if isChw() && validPatient()
    && incoming().chwId == uid() && incoming().healthCenterId == hc();
  allow update: if isChw() && existing().chwId == uid() && validPatient()
    && same('chwId') && same('healthCenterId') && same('shortId') && same('createdAt');
  allow delete: if false; // archive instead (archivedAt)
}
```

`lib/data/forms/validation.dart`, one range class, polite message:

```dart
String? check(num? v) {
  if (v == null) return 'Required';
  return contains(v) ? null : 'Enter $min to $max $unit';
}
const temperatureC = NumberRange(30, 45, '°C');
```

**Terms:** offline-first, drift, SQLCipher, transaction, outbox queue, soft delete, security rules, `hasOnly`, composite index, normalised data, repository pattern (domain interface in `domain/repositories`, implementation in `data/repositories`).

---

## Person 3 (6:00 to 9:00): Urgent alerts, offline SMS, sync, and the two-widget state update

**Rubric items:** State Management (10), action 5, Clean Architecture.

**On screen:** record a visit with a danger sign, tap Send urgent alert. Show Home's urgent card and the connection pill, and the Alerts screen, change together. Then airplane mode and send by SMS. Sync screen with a Retry.

### Script

> **(6:00)** "I am [name]. I did urgent alerts and sync. First, the **state-management** requirement: a single state change that updates two widgets. I record a visit with a danger sign and tap **Send urgent alert**."
>
> **(6:20)** "Watch two places. [point] The red card on Home, and the Alerts screen. Both read the same Riverpod provider, `allDispatchesProvider`, which is a **StreamProvider** over the local database. When the dispatch state moves from sending to confirmed, **both widgets rebuild from one source of truth**, with no manual refresh and no `setState`. The connection pill on Home is a second provider, `isOnlineProvider`, so I can flip it too."
>
> **(6:55)** "How it works: `UrgentDispatcher.send` first tries the internet with a **10-second timeout**. [Console] The visit and alert arrive in Firestore together. If that fails, it falls back to SMS."
>
> **(7:20)** "Now airplane mode, and send again. [do it] The app builds a compact message with a **codec**, encrypted with **AES-256-GCM**, with the header as **associated data**, so a body cannot be replayed under another device. It sends to the **Africa's Talking** number. The server decrypts it, creates a partial case, and replies with an **HMAC-signed** `HB OK` code. The app ignores any ack whose tag does not match its key, so only our server can confirm. If nothing comes back in **10 minutes**, the card offers **Resend** and **Call**."
>
> **(8:05)** "When the phone is back online, the full visit syncs and **merges into the same case**, so the supervisor sees one case, not two. The **sync engine** drains the outbox, and the **Sync screen** shows pending items with a Retry button. Background sync runs through **workmanager**."
>
> **(8:35)** "Architecture: the dispatcher is plain Dart in `lib/urgent`, with a sender interface, so the Android SMS part is swapped in tests. The codec has shared **test vectors** that both Dart and TypeScript must pass, so the two sides stay byte-identical. Over to [Person 4]."

### Snippets

`lib/urgent/urgent_dispatcher.dart`, internet first, SMS fallback:

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
```

Signed acknowledgement check:

```dart
if (parts[1] != await ackTag(device.smsKey, parts[0])) continue; // not from our server
await acknowledge(parts[0]);
```

`lib/presentation/home/home_screen.dart`, one provider, a widget reacting to it:

```dart
final dispatches = ref.watch(allDispatchesProvider).value ?? const [];
...
final alert = switch (state) {
  DispatchState.confirmed => 'the health centre has the alert',
  DispatchState.sentSms || DispatchState.unconfirmed => 'alert sent by SMS, not confirmed yet',
  DispatchState.sending => 'alert is sending',
  null => 'alert not sent yet',
};
```

**Terms:** `StreamProvider`, single source of truth, AES-GCM, associated data, HMAC, partial case merge, idempotent sync, outbox, workmanager, background isolate.

---

## Person 4 (9:00 to 12:00): Supervisor flow and navigation

**Rubric items:** Design Match and Navigation (10), action 3, Widgets and UI, State Management.

**On screen:** sign in as a supervisor. Walk the four tabs: Alerts, CHWs, Patients, Profile. Open a case, add a note, change status, show the snackbar. Open a CHW and a patient history. Use back each time. Then briefly the CHW Home stat cards.

### Script

> **(9:00)** "I am [name]. I did the supervisor side. I sign in as a supervisor; the **role claim** in the token decides which app shell I get. The shell is a **bottom navigation** over an **IndexedStack**, so each tab keeps its scroll and state."
>
> **(9:20)** "**Alerts** is the inbox: urgent cases first, with status filters. It is a **StreamProvider.autoDispose** that polls every 10 seconds. I open a case. [show] The detail shows the patient, the danger signs and the history of status events."
>
> **(9:50)** "I add a note and press **Escalate**. The status follows a **state machine** called `TRANSITIONS`: new can go to reviewed, escalated, follow-up or resolved; resolved goes nowhere. The check is on the server, inside a Firestore **transaction**, so two supervisors cannot overwrite each other, and each change adds an event to a subcollection. The app shows a **snackbar**, 'Case moved to Escalated', and refreshes the inbox through `ref.invalidate`. The CHW gets an SMS on Escalate."
>
> **(10:35)** "**CHWs** tab: I tap a CHW and see their visit history; I tap a visit and see its detail. **Patients** tab: search, open a patient, see their profile and full history. In each, **back** returns exactly one level, with no back-stack errors."
>
> **(11:15)** "Everything is **scoped by health centre on the server**. If I request a CHW from another centre I get a 404, not an empty list. And on the CHW side, the Home screen has **stat cards**: visited today, due for a visit, urgent today. They are computed from three providers, so they change when a visit is saved."
>
> **(11:45)** "These screens were matched to our Figma file: Outfit font, green and lime palette, 24-pixel cards. Over to [Person 5]."

### Snippets

`lib/presentation/supervisor/case_screen.dart`, action, snackbar:

```dart
Future<void> _move(AlertStatus to) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await ref.read(caseStatusProvider(widget.alertId).notifier)
      .move(to, _note.text);
  if (error == null) _note.clear();
  messenger.showSnackBar(SnackBar(content: Text(error ?? 'Case moved to ${to.label}')));
}
```

`server/src/supervisor/routes.ts`, server-side state machine:

```ts
const TRANSITIONS: Record<AlertStatus, AlertStatus[]> = {
  new: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  reviewed: ['escalated', 'follow_up', 'resolved'],
  escalated: ['follow_up', 'resolved'],
  follow_up: ['escalated', 'resolved'],
  resolved: [],
};
// inside fs.runTransaction: re-read the status, reject an illegal move, write an events/ doc
```

`lib/presentation/home/home_screen.dart`, the stat cards:

```dart
SummaryRow(children: [
  Expanded(child: SummaryCard(icon: Icons.check, value: visited, label: 'Visited today', ...)),
  Expanded(child: SummaryCard(icon: Icons.event, value: due.length, label: 'Due for a visit', ...)),
  Expanded(child: SummaryCard(icon: Icons.warning_amber_rounded, value: urgent.length, label: 'Urgent today', ...)),
]);
```

**Terms:** role-based shell, `IndexedStack`, `FutureProvider.family`, `ref.invalidate`, state machine, Firestore transaction, optimistic concurrency, tenant scoping, `MaterialPageRoute` back stack.

---

## Person 5 (12:00 to 15:00): Design system, admin, responsive layout and tests

**Rubric items:** Widgets and UI (5), Design Match (10), Code Quality (5), Testing (5), action 3 (rotate once).

**On screen:** sign in as admin: Resets, New account, Centres, Profile. Approve a reset. Create a member while the Console shows `users`. Open a member, deactivate. Open a centre. Rotate the phone to landscape once, no overflow.

### Script

> **(12:00)** "I am [name]. I did the design system and the admin screens. As admin I get a different shell, from the same `role` claim. **Resets**: I approve a request; the server issues a one-time code. **New account**: I create a CHW. [Console] The `users` document appears; the server texted a temporary PIN, never stored in the document. **Members** has two tabs, CHWs and Supervisors."
>
> **(12:40)** "I open a member and **deactivate**. The server does three things: sets `active: false` in Firestore, **disables the Auth user**, and **revokes the refresh tokens**, so the person is locked out at once, not at the next sign-in. **Delete** removes the account, credentials and devices but keeps the patients and visits. An admin account can never be changed through this screen. A centre name opens the centre details."
>
> **(13:25)** "Now **rotation**. [rotate once] No overflow in landscape. We prove this with **layout tests** at four sizes: 320 by 568, 430 by 932, and two landscape sizes, including **extra-large text**. Any RenderFlex overflow fails the build. So the layout is checked on phones under 5.5 inches and over 6.7."
>
> **(13:50)** "The widgets come from one **design system**: `HbButton` is a 56-pixel pill, `HbCard` has 24-pixel corners, plus avatar, chip, pill, circle button, floating tab bar, bottom sheet and snackbar. Colours are **tokens** in `HbColors`, and we measured **contrast**: text on brand green is 4.9 to 1 and on red 5 to 1, above the 4.5 requirement. Tap targets are at least 48 pixels."
>
> **(14:25)** "Quality: `flutter analyze` reports **no issues**, and **129 tests** pass with coverage above 70 percent; server has 48 tests on the Firebase emulators and the dashboard 35. Thank you for watching."

### Snippets

`lib/core/widgets/widgets.dart`, one button for every screen:

```dart
HbButton(label, onPressed: ..., kind: HbButtonKind.primary)  // 56 dp StadiumBorder,
// Opacity 0.5 and no tap when onPressed is null
```

`test/layout_test.dart`, overflow checked at four sizes:

```dart
const _sizes = {
  'small phone (320x568)': (Size(320, 568), 0.55),
  'large phone (430x932)': (Size(430, 932), 0.55),
  'landscape (844x390)': (Size(844, 390), 0.55),
  'landscape, extra large text': (Size(844, 390), 0.72),
};
```

`server/src/admin/routes.ts`, deactivate cuts access immediately:

```ts
await fb.auth.updateUser(id, { disabled: !active });
if (!active) await fb.auth.revokeRefreshTokens(id);
await users.doc(id).update({ active });
```

**Terms:** design tokens, Material 3 theme (`buildTheme`), contrast ratio (WCAG 4.5:1), tap-target size, `RenderFlex` overflow, responsive layout, widget tests, `ProviderScope` overrides, coverage, custom-claim role guard (`requireRole('admin')`), soft deactivate versus delete.

---

## Hand-offs (one sentence each)

1. to 2: "Accounts and settings are in place; [Name] will now show the data side with the Firebase Console."
2. to 3: "Data is stored and synced; [Name] will show how an urgent alert and shared state work."
3. to 4: "The alert has reached the centre; [Name] will show what the supervisor does with it."
4. to 5: "[Name] will finish with the admin side, the design system and the tests."

## Honest notes

- **Rubric versus code snippets:** no slide deck is allowed, so say the file name and term aloud and keep the code for the report.
- **If you run long:** drop the Forgot PIN sentence (1), the search demo (2), the Resend/Call sentence (3), the CHW stat cards (4), the delete sentence (5).
- **Web dashboards** are not in the phone rubric. Optional 20 seconds each at the end of your part, only if time remains.

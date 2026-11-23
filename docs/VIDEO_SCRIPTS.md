# Video demo scripts (15 minutes, five people)

One continuous recording, 1080p, no cuts, no speed-ups, no slide deck, no team introductions. The release APK runs on a physical phone. The assignment also asks that every member presents an aspect, and that the video shows both sign-in methods, CRUD with the Firebase Console visible, and the app on a real device.

All paths are from the project root (`HealthBridge_v2/`). **Line numbers were read from the code on branch `feat/redesign` at commit `fa712c6`.** If you edit a file before recording, re-check them (open the file and search for the symbol named in the table).

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

**How code is shown without a slide deck:** keep the laptop on the same table. Each person opens the named file in the editor (large font), jumps to the line numbers in their table (Ctrl+G in VS Code), and the recording captures the screen or a second camera points at it. Say the file name and the term aloud. If the lecturer does not allow showing code at all, speak the same script and keep the snippets for the report.

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

A step-by-step version of this tour, with what to do, what to say, and what to point at in the Firebase Console, is in [DEMO_TOUR_SCRIPT.md](DEMO_TOUR_SCRIPT.md).

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

Each person says **one assignment question** ("be prepared to explain") plus their best code. Keep to the clock. Each table below lists every file you present, the line range to open, and what to point at.

## Person 1 (5:00 to 7:00): authentication, SharedPreferences, why Riverpod

**Assignment question:** why this state management is appropriate.

> "I did authentication and local preferences. We chose **Riverpod** because state is compile-checked, testable without a `BuildContext`, and rebuilds only the widgets that watch it. We use no `setState`."
>
> "[login_controller.dart] Sign-in is one `Notifier`, `LoginController`, with three methods: PIN, SMS code, email. Validators like `validatePin` run in the form, so the screen has no logic. Success sets the session provider and the root widget swaps the screen."
>
> "[server auth/routes.ts] The PIN goes to our server, which checks an **Argon2 hash**, counts failures, and **locks the account for 15 minutes after five**. Then it returns a **Firebase custom token** with **custom claims**: role and health centre. A new account is also flagged to choose its own PIN first. Forgot PIN uses an **OTP**: 30 minutes, five tries."
>
> "[settings.dart] **SharedPreferences**: three preferences, restored in `build()` and saved on every change, which is why they survived the restart."

### Files and lines

| File | Lines | Point at |
|---|---|---|
| `lib/presentation/auth/login_controller.dart` | 9 | `enum LoginMethod { pin, smsCode, email }`: the three methods |
| | 43-57 | `LoginController extends Notifier<LoginState>` and `submit` |
| | 125-127, 141-143 | `validatePin`, `validatePassword`: the polite messages |
| `lib/core/settings/settings.dart` | 41-63 | `SettingsController` and `build()`: restore on launch |
| | 77-80 | `setTextSize`: state first, then saved |
| | 103-105 | `settingsProvider` |
| `server/src/auth/routes.ts` | 19 | `MAX_FAILED_LOGINS = 5` |
| | 42-66 | `POST /pin`: lockout and custom token |

### Snippets

`lib/presentation/auth/login_controller.dart`, lines 43-57:

```dart
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthService get _auth => ref.read(authServiceProvider);

  void choose(LoginMethod method) => state = LoginState(method: method);

  /// Phone + PIN, or email + password.
  Future<void> submit(String id, String secret) => _run(
    id,
    () => state.method == LoginMethod.email
        ? _auth.signInWithEmail(id.trim(), secret)
        : _auth.signInWithPin(normalizePhone(id), secret),
  );
```

`lib/presentation/auth/login_controller.dart`, lines 125-127 and 141-143:

```dart
String? validatePin(String? v) =>
    requiredField(v) ??
    (RegExp(r'^\d{4,6}$').hasMatch(v!.trim()) ? null : 'PIN is 4 to 6 digits');

String? validatePassword(String? v) =>
    requiredField(v) ??
    (v!.length >= 8 ? null : 'Password is at least 8 characters');
```

`lib/core/settings/settings.dart`, lines 49-63 and 77-80:

```dart
  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    final remember = p.getBool(_remember) ?? false;
    return AppSettings(
      textSize:
          TextSize.values.asNameMap()[p.getString(_textSize)] ??
          TextSize.normal,
      defaultVisitType:
          VisitType.values.asNameMap()[p.getString(_visitType)] ??
          VisitType.maternal,
      rememberLogin: remember,
      savedLoginId: remember ? p.getString(_loginId) : null,
    );
  }

  Future<void> setTextSize(TextSize size) async {
    state = _with(textSize: size);
    await _prefs.setString(_textSize, size.name);
  }
```

`server/src/auth/routes.ts`, lines 51-65:

```ts
    if (cred.lockedUntil && (cred.lockedUntil as Timestamp).toMillis() > Date.now()) {
      throw new HttpError(429, 'too_many_attempts');
    }
    if (!(await verify(cred.pinHash, given))) {
      const locks = (cred.failedLogins ?? 0) + 1 >= MAX_FAILED_LOGINS;
      await credRef.update(
        locks
          ? { failedLogins: 0, lockedUntil: Timestamp.fromMillis(Date.now() + LOCK_MS) }
          : { failedLogins: FieldValue.increment(1) },
      );
      throw unauthorized();
    }
    if (cred.failedLogins || cred.lockedUntil) await credRef.update({ failedLogins: 0, lockedUntil: null });
    const claims = { role: user.role, hc: user.healthCenterId };
    res.json({ customToken: await fb.auth.createCustomToken(user.id, claims) });
```

Terms: custom token, custom claims, Argon2, lockout (429), OTP, `Notifier`, `ref.watch`, persisted preferences.

## Person 2 (7:00 to 9:00): Firestore CRUD, ERD to Firestore, security rules

**Assignment questions:** how the ERD matches the database; how the rules protect data.

> "I did patients, visits and the data model. Our ERD in `docs/ERD.md` has `users`, `healthCenters`, `patients`, `visits` and `alerts`. The Firestore collections match it field for field, in camelCase. A visit stores only `patientId`, never the patient's data, so nothing is duplicated."
>
> "[patients_repository.dart] **Create** writes the patient to the encrypted local database, **drift on SQLCipher**, and an **outbox** row in the same transaction. A record can never be saved without being queued. Sync uploads it, which is what you saw appear in the Console. **Read** is a drift stream, so the list updates live. **Update** re-queues. **Delete** is `archive`: it sets `archivedAt`."
>
> "[firestore.rules] Why archive: the rules say `allow delete: if false`. A CHW reads and writes only their own patients; a supervisor reads only their centre's; `chwId`, `healthCenterId`, `shortId` and `createdAt` cannot change after creation; and a visit's `isUrgent` must equal `dangerSigns.size() > 0`, so a client cannot fake urgency. Indexes are in `firestore.indexes.json`."

### Files and lines

| File | Lines | Point at |
|---|---|---|
| `docs/ERD.md` | whole file | the entities and their fields; compare with the Console |
| `lib/domain/repositories/patient_repository.dart` | 7 | `abstract interface class PatientRepository`: the domain interface |
| `lib/data/repositories/patients_repository.dart` | 21 | `create(...)` |
| | 32-49 | `_db.transaction`: patient row plus `_enqueue` |
| | 54 | `update` (re-queues) |
| | 65 | `archive`: sets `archivedAt` |
| | 79 | `watch`: the live stream with search |
| | 91 | `_enqueue`: the outbox row |
| `firestore.rules` | 76-85 | `match /patients`: read, create, update, `allow delete: if false` |
| | 89-106 | `validVisit`, especially 101 (`isUrgent` rule) |
| `firestore.indexes.json` | 2 | `"indexes"` |
| `lib/data/forms/validation.dart` | 3-16 | `NumberRange` and `check` |
| | 18 | `temperatureC = NumberRange(30, 45, ...)` |

### Snippets

`lib/data/repositories/patients_repository.dart`, lines 32, 46-49 (the transaction) and 65-67:

```dart
    return _db.transaction(() async {
      final row = PatientsCompanion.insert(/* ...fields... */ syncState: const Value(SyncState.queued));
      final patient = await _db.into(_db.patients).insertReturning(row);
      await _enqueue(patient);
      return patient;
    });

  /// The app's "delete": hides the patient everywhere but keeps the record, and syncs like an edit.
  @override
  Future<Patient> archive(Patient p) =>
      update(p.copyWith(archivedAt: Value(_now())));
```

`firestore.rules`, lines 76-85:

```
    match /patients/{patientId} {
      allow read: if (isChw() && existing().chwId == uid())
        || (isSupervisor() && existing().healthCenterId == hc());
      allow create: if isChw() && validPatient()
        && incoming().chwId == uid() && incoming().healthCenterId == hc();
      // Edits and archiving; owner, centre, short ID and creation time never change.
      allow update: if isChw() && existing().chwId == uid() && validPatient()
        && same('chwId') && same('healthCenterId') && same('shortId') && same('createdAt');
      allow delete: if false; // archive instead (archivedAt); health records are kept
    }
```

`firestore.rules`, lines 100-101:

```
        // Urgent exactly when a danger sign is ticked, so the app cannot get the two out of step.
        && v.isUrgent == (v.dangerSigns.size() > 0)
```

`lib/data/forms/validation.dart`, lines 3-18:

```dart
class NumberRange {
  const NumberRange(this.min, this.max, this.unit);
  // ...
  /// Null when [v] is valid, otherwise a message naming the allowed range.
  String? check(num? v) {
    if (v == null) return 'Required';
    return contains(v) ? null : 'Enter $min to $max $unit';
  }
}

const temperatureC = NumberRange(30, 45, '°C');
```

Terms: offline-first, SQLCipher, transaction, outbox, soft delete, `hasOnly`, owner-limited rules, composite index, repository interface (domain) and implementation (data).

## Person 3 (9:00 to 11:00): urgent alerts, sync and shared state

**Assignment question:** state management in action across components.

> "I did urgent alerts and sync. The Home alert card and the stat card you saw both read one provider, `allDispatchesProvider`, a **StreamProvider** over the local database. When the dispatch state changes, both widgets rebuild from **one source of truth**. The connection pill reads `isOnlineProvider`."
>
> "[urgent_dispatcher.dart] `send` tries the internet with a **10-second timeout**. If that fails it falls back to SMS. [codec.dart] The SMS is encrypted with **AES-256-GCM**, with the header as **associated data**, so a message cannot be replayed under another device. The server decrypts it, makes a partial case, and replies with an **HMAC-signed** `HB OK` code. The app ignores acknowledgements whose tag does not match, so only our server can confirm. After 10 minutes with no ack, the card offers Resend and Call."
>
> "When the phone is back online the full visit uploads and **merges into the same case**. The **sync engine** drains the outbox; **workmanager** runs it in the background."

### Files and lines

| File | Lines | Point at |
|---|---|---|
| `lib/presentation/home/home_screen.dart` | 30-33 | `ref.watch(isOnlineProvider)` and `ref.watch(allDispatchesProvider)` |
| | 91-122 | `SummaryRow` of the three stat cards (urgent count comes from line 47) |
| | 199-222 | `_UrgentCard` and the `switch (state)` on `DispatchState` |
| `lib/urgent/urgent_dispatcher.dart` | 67-77 | `send`: internet with timeout, SMS fallback |
| | 79-102 | `sendSms`: `seal(...)` then `sender.send` |
| | 104 | `expire`: the 10-minute rule |
| | 113-124 | `applyAcks`, with the tag check on line 121 |
| `lib/core/sms/codec.dart` | 1-8 | header comment: AES-256-GCM, header as associated data |
| | 30 | `AesGcm.with256bits()` |
| | 109 | `seal(...)` |
| | 214-226 | `ackTag`: the HMAC |
| `lib/sync/sync_engine.dart` | 46, 78 | `class SyncEngine`, `run()` |

### Snippets

`lib/presentation/home/home_screen.dart`, lines 30-33 and 214-220:

```dart
    final online = ref.watch(isOnlineProvider);
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final dispatches = ref.watch(allDispatchesProvider).value ?? const [];

    final alert = switch (state) {
      DispatchState.confirmed => 'the health centre has the alert',
      DispatchState.sentSms ||
      DispatchState.unconfirmed => 'alert sent by SMS, not confirmed yet',
      DispatchState.sending => 'alert is sending',
      null => 'alert not sent yet',
    };
```

`lib/urgent/urgent_dispatcher.dart`, lines 67-77 and 119-122:

```dart
  Future<void> send(String visitId) async {
    await _repo.start(visitId);
    try {
      await _postAlert(visitId).timeout(internetTimeout);
      await _repo.updateState(visitId, DispatchState.confirmed);
    } on Exception {
      await sendSms(visitId);
    }
  }

      final parts = ack.split(' ');
      if (parts.length != 2) continue; // unsigned or malformed
      if (parts[1] != await ackTag(device.smsKey, parts[0])) continue;
      await acknowledge(parts[0]);
```

`lib/core/sms/codec.dart`, lines 214-226:

```dart
/// The tag the server puts on an acknowledgement, `HB OK <code> <tag>`: the first 12 hex of
/// HMAC-SHA256 over "HB OK <code>" with the device's SMS key. Only a reply carrying the right tag
/// confirms an alert, so a stranger who learns a short code cannot fake one.
Future<String> ackTag(List<int> key, String shortCode) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('HB OK $shortCode'),
    secretKey: SecretKey(key),
  );
  return mac.bytes
      .take(6)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
```

Terms: `StreamProvider`, single source of truth, AES-GCM, associated data, HMAC, idempotent merge, outbox, workmanager. Shared test vectors (`shared/sms-vectors.json`) keep the Dart and TypeScript codecs byte-identical.

## Person 4 (11:00 to 13:00): clean architecture and the supervisor case flow

**Assignment question:** how the code follows clean architecture.

> "Now the code. Our app is in three layers under `lib/`. **Presentation** holds screens, each with a Riverpod controller beside it. **Domain** holds entities, repository interfaces and use cases. **Data** holds the drift database and repositories that implement those interfaces. Screens never talk to Firebase or the database directly; the repository pattern keeps logic out of UI files."
>
> "[case_screen.dart] The case screen only collects input and shows a snackbar. The work is in `CaseStatusController`: it calls the server, then `ref.invalidate`s the case and the inbox so the UI refreshes at once, and any error comes back as a snackbar message."
>
> "[server supervisor/routes.ts] The status change is a **state machine**, `TRANSITIONS`. The server re-reads the status inside a Firestore **transaction**, rejects an illegal move, and writes an event to a subcollection, so two supervisors cannot overwrite each other and every change has an author. All supervisor queries are **scoped by health centre on the server**; another centre's CHW returns 404."

### Files and lines

| File | Lines | Point at |
|---|---|---|
| folders | `lib/presentation/`, `lib/domain/` (entities, repositories, usecases), `lib/data/` | the three layers, in the editor's file tree |
| `lib/presentation/shell/role_shells.dart` | 42 | `IndexedStack(index: index, children: pages)`: the tabs keep their state |
| `lib/presentation/supervisor/case_screen.dart` | 33-42 | `_move`: input, snackbar |
| `lib/presentation/supervisor/supervisor_controllers.dart` | 19-28 | `inboxProvider`: a `StreamProvider.autoDispose` polling every 10 s |
| | 30-32 | `caseProvider`: `FutureProvider.autoDispose.family` |
| | 39-64 | `CaseStatusController.move`, with `ref.invalidate` on lines 54-55 |
| `server/src/supervisor/routes.ts` | 19-26 | `TRANSITIONS` |
| | 194-224 | `PATCH /alerts/:id`, transaction on 200-213 |

### Snippets

`lib/presentation/supervisor/case_screen.dart`, lines 33-42:

```dart
  Future<void> _move(AlertStatus to) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(caseStatusProvider(widget.alertId).notifier)
        .move(to, _note.text);
    if (error == null) _note.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Case moved to ${to.label}')),
    );
  }
```

`lib/presentation/supervisor/supervisor_controllers.dart`, lines 48-64:

```dart
  Future<String?> move(AlertStatus to, String note) async {
    state = true;
    try {
      await ref
          .read(supervisionRepositoryProvider)
          .setStatus(alertId, to, note: note);
      ref.invalidate(caseProvider(alertId));
      ref.invalidate(inboxProvider);
      return null;
    } on Exception catch (e) {
      return e.toString().contains('invalid_transition')
          ? 'Someone else changed this case. It has been refreshed.'
          : 'Could not save. Check your connection and try again.';
    } finally {
      if (ref.mounted) state = false;
    }
  }
```

`server/src/supervisor/routes.ts`, lines 19-26 and 199-213:

```ts
// Where a case can go next. 'new' is only ever the starting state, and a resolved case stays closed.
export const TRANSITIONS: Record<Status, Status[]> = {
  new: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  reviewed: ['escalated', 'follow_up', 'resolved'],
  escalated: ['follow_up', 'resolved'],
  follow_up: ['escalated', 'resolved'],
  resolved: [],
};

    const eventRef = ref.collection('events').doc();
    const from = await fs.runTransaction(async (tx) => {
      // Re-read inside the transaction: if another supervisor got there first, the transition is re-checked.
      const current = (await tx.get(ref)).data()!.status as Status;
      if (!TRANSITIONS[current].includes(status)) throw new HttpError(409, 'invalid_transition');
      tx.update(ref, { status });
      tx.create(eventRef, {
        actorId: uid,
        fromStatus: current,
        toStatus: status,
        note: note || null,
        createdAt: FieldValue.serverTimestamp(),
      });
      return current;
    });
```

Terms: presentation, domain, data, repository interface, `FutureProvider.family`, `ref.invalidate`, role-based shell with `IndexedStack`, Firestore transaction, tenant scoping, HTTP 409.

## Person 5 (13:00 to 14:45): design system, layout tests, quality and GitHub history

**Assignment questions:** how testing validates the app; how GitHub history shows collaboration.

A snippet-by-snippet version of this section, with timings, is in [PERSON5_SCRIPT.md](PERSON5_SCRIPT.md).

> "I did the design system, the admin screens and testing. [widgets.dart] Every screen uses one set of widgets: `HbButton`, a 56-pixel pill; `HbCard`, 24-pixel corners; chips, avatars, a floating tab bar. Colours are tokens in `HbColors`, with contrast measured: 4.9 to 1 on brand green, 5 to 1 on red, above the 4.5 requirement, and tap targets at least 48 pixels."
>
> "[layout_test.dart] To prove it works on small and large phones and in landscape, a **widget test** renders every main screen at four sizes: 320 by 568, 430 by 932, landscape, and landscape with extra-large text. Any `RenderFlex` overflow fails the test."
>
> "[terminal] `flutter analyze` reports [say the real result]. `flutter test` runs [say the real number] tests, with [say the real number] percent coverage; the server has its own tests on the Firebase emulators, and the dashboard has its own."
>
> "[terminal, `git shortlog -sn`] Our history shows every member's commits and branches over the weeks, and the contribution tracker matches it. On the admin side, deactivating a member disables the Auth user and revokes their tokens, so they are locked out at once. Thank you for watching."

### Files and lines

| File | Lines | Point at |
|---|---|---|
| `lib/core/widgets/widgets.dart` | 6 | `class HbCard` (24 px corners) |
| | 84-143 | `HbButton`: four kinds, 56 px high (line 112), `StadiumBorder` (115), 50% opacity when disabled (109) |
| `lib/core/theme/app_theme.dart` | 5-28 | `HbColors`; contrast comments on lines 17, 21, 25 |
| | 126 | `buildTheme()` |
| `test/layout_test.dart` | 24-31 | the four sizes in `_sizes` |
| `server/src/admin/routes.ts` | 25 | `router.use(requireUser(fb), requireRole('admin'))` |
| | 120-129 | `PATCH /users/:id`: deactivate |
| terminal | | `flutter analyze`, `flutter test --coverage`, `git shortlog -sn` |

### Snippets

`lib/core/widgets/widgets.dart`, lines 100-122 (abridged):

```dart
    final (bg, fg) = switch (_kind) {
      _ButtonKind.primary => (HbColors.ink, Colors.white),
      _ButtonKind.secondary => (HbColors.white, HbColors.ink),
      _ButtonKind.danger => (HbColors.red, Colors.white),
      _ButtonKind.light => (HbColors.white, HbColors.ink),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: bg,
          shape: StadiumBorder(/* ... */),
```

`lib/core/theme/app_theme.dart`, lines 17-26:

```dart
  /// Input and checkbox edges: 3.3:1 on the canvas, the minimum for a control's boundary.
  static const edge = Color(0xFF7E8A85);
  static const chevron = Color(0xFFB5BEBA);

  /// Secondary text on brand green (4.9:1).
  static const onBrand = Color(0xFFD7EAE3);
  static const red = Color(0xFFB3261E);

  /// Secondary text on the red (5:1).
  static const onRed = Color(0xFFFFE3E0);
```

`test/layout_test.dart`, lines 24-31:

```dart
// (size, text scale): 0.55 brings the wide test font (Ahem) close to Inter; 0.72 is that times the
// Settings screen's "Extra large" (1.3).
const _sizes = {
  'small phone (320x568)': (Size(320, 568), 0.55),
  'large phone (430x932)': (Size(430, 932), 0.55),
  'landscape (844x390)': (Size(844, 390), 0.55),
  'landscape, extra large text': (Size(844, 390), 0.72),
};
```

`server/src/admin/routes.ts`, lines 120-128:

```ts
  /** Switches an account off or on. Off: no PIN, SMS or password sign-in, and open sessions end at once. */
  router.patch('/users/:id', async (req, res) => {
    const { active } = z.object({ active: z.boolean() }).parse(req.body);
    const { ref } = await member(req.params.id);
    await ref.update({ active });
    await fb.auth.updateUser(ref.id, { disabled: !active });
    if (!active) await fb.auth.revokeRefreshTokens(ref.id);
    await audit(fb, callerOf(res).uid, active ? 'user.activate' : 'user.deactivate', 'users', ref.id);
    res.json({ id: ref.id, active });
  });
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

# Person 4: the script, snippet by snippet (11:00 to 13:00)

Topic: clean architecture and the supervisor case flow. About 2 minutes, roughly 270 spoken words. Person 4 also gives the 5-minute app and dashboard tour at the start of the video (0:00 to 5:00); that part is in [VIDEO_SCRIPTS.md](VIDEO_SCRIPTS.md). Line numbers below were read at commit `fa712c6`.

**Assignment question you answer:** how the code follows clean architecture.

## Order and timing

| Time | Show | Say (the short version) |
|---|---|---|
| 11:00 | editor file tree: `lib/presentation`, `lib/domain`, `lib/data` | the three layers |
| 11:20 | `lib/presentation/supervisor/case_screen.dart`, lines 33-42 | the screen only collects input |
| 11:40 | `lib/presentation/supervisor/supervisor_controllers.dart`, lines 48-64 | the controller does the work |
| 12:10 | `server/src/supervisor/routes.ts`, lines 19-26 | the state machine |
| 12:25 | same file, lines 199-213 | the transaction |
| 12:55 | spoken only | scoping |

## 1. The three layers: the file tree (20 seconds)

Show `lib/` in the editor with three folders open:
- `lib/presentation/`: screens, each with a controller beside it
- `lib/domain/`: `entities/`, `repositories/` (interfaces such as `patient_repository.dart`), `usecases/`
- `lib/data/`: the drift database and the repositories that implement the domain interfaces

**Say:** "Now the code. The app is in three layers. Presentation holds the screens, each with a Riverpod controller beside it. Domain holds entities, repository interfaces and use cases, plain Dart with no Flutter and no Firebase. Data holds the database and the repositories that implement those interfaces. Screens never talk to Firebase or the database directly, so no business logic sits in the UI files."

**Brief notes:** `lib/presentation/shell/role_shells.dart` line 42 uses an `IndexedStack`, so each tab keeps its scroll position and state when you switch.

## 2. The screen only collects input: `case_screen.dart` lines 33-42 (20 seconds)

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

**Say:** "This is the case screen's whole job when a supervisor presses Escalate. It reads the controller, passes the new status and the note, and shows a snackbar with either the error or 'Case moved to Escalated'. It clears the note only on success."

**Brief notes:** the messenger is taken before the `await`, so the snackbar is safe even if the screen changes while waiting. `caseStatusProvider(widget.alertId)` is a family provider: one controller per case.

## 3. The controller does the work: `supervisor_controllers.dart` lines 48-64 (30 seconds)

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

**Say:** "The controller sets a saving flag, which disables the buttons, and calls the repository. On success it invalidates two providers, the case and the inbox, so both refresh at once without the user pulling to refresh. On failure it returns a friendly message, and a special one if someone else changed the case first. The `finally` always clears the saving flag."

**Brief notes:** `state` here is just a boolean (saving or not). It returns `null` for success or a message to show, so the screen needs no try/catch of its own.

## 4. The state machine: `server/src/supervisor/routes.ts` lines 19-26 (15 seconds)

```ts
// Where a case can go next. 'new' is only ever the starting state, and a resolved case stays closed.
export const TRANSITIONS: Record<Status, Status[]> = {
  new: ['reviewed', 'escalated', 'follow_up', 'resolved'],
  reviewed: ['escalated', 'follow_up', 'resolved'],
  escalated: ['follow_up', 'resolved'],
  follow_up: ['escalated', 'resolved'],
  resolved: [],
};
```

**Say:** "Which status changes are allowed is a small table on the server: from new you can go anywhere except back to new, and a resolved case stays closed."

## 5. The transaction: `server/src/supervisor/routes.ts` lines 199-213 (30 seconds)

```ts
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

**Say:** "The change runs inside a Firestore transaction. It reads the current status again inside the transaction, so two supervisors cannot overwrite each other. An illegal move returns HTTP 409, which the app turns into the friendly message you just saw. A legal one updates the status and writes an event record, who, from, to, note and server time, so every change has an author and a history."

**Brief notes:** `tx.create` on the `events` subcollection is what the case history on the screen reads. The server also texts the CHW on Escalate and Follow-up.

## 6. Scoping (5 seconds, spoken only)

**Say:** "Every supervisor query is scoped to their own health centre on the server, so another centre's CHW returns a 404, not an empty list."

## Hand-off

"[Name] closes with the design system and the tests."

## If you run long

Drop section 4 (the table is visible in the snippet in section 5's context) and the scoping sentence.

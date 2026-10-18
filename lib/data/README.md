# lib/data: the contract for the screens

Everything here works offline. Screens only talk to the Riverpod providers in `providers.dart`.

## Startup

```dart
final db = await openAppDatabase(); // SQLCipher; the key lives in the Android Keystore
runApp(ProviderScope(
  overrides: [databaseProvider.overrideWithValue(db)],
  child: const App(),
));
```

## Providers

| Provider | Type | Use |
| --- | --- | --- |
| `patientsRepositoryProvider` | `PatientsRepository` | `create(...)`, `update(patient)`, `get(id)`, `watch(query:)` for the list and search |
| `visitsRepositoryProvider` | `VisitsRepository` | `record(patientId, type, answers, signCodes, ...)`, `get`, `watchForPatient`, `signCodes` |
| `draftsRepositoryProvider` | `DraftsRepository` | `save(screen, map)`, `load(screen)`, `delete(screen)` for form autosave |
| `dangerSignsRepositoryProvider` | `DangerSignsRepository` | `forType(VisitType)` for the danger-signs step |

Models are drift's generated rows (`Patient`, `Visit`, `DangerSign`, `Draft`) plus the enums in `models.dart`.

## Rules the repositories enforce

- Every create or update writes the row and its outbox row in one transaction. Do not write to the tables directly.
- IDs are UUID v4 made on the phone. `Visit.shortCode` is the first 8 hex of the ID; `Patient.shortId` is `P` plus 6 hex.
- `Visit.isUrgent` is derived from the ticked sign codes (`isUrgent()` in `forms/danger_signs.dart`); do not pass it in.
- `syncState` is `local | queued | synced | failed` and is what the per-record status badge should show. New records start `queued`.
- Dates come back as local `DateTime`; they are stored and uploaded as UTC.

## Validation

`forms/validation.dart` has `temperatureC`, `muacMm` and `gestationalWeeks`; use `range.check(value)` as a
form validator (null means valid). The ranges and the danger-sign list in `forms/danger_signs.dart` are
placeholders until the Figma forms and a clinician confirm them. Kinyarwanda labels are empty on purpose.
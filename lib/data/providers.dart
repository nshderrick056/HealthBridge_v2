import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/auth/auth_service.dart';
import 'db.dart';
import 'repositories/danger_signs_repository.dart';
import 'repositories/drafts_repository.dart';
import 'repositories/patients_repository.dart';
import 'repositories/urgent_repository.dart';
import 'repositories/visits_repository.dart';

/// Must be overridden at startup with the opened database:
/// `ProviderScope(overrides: [databaseProvider.overrideWithValue(await openAppDatabase())], ...)`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override databaseProvider'),
);

final patientsRepositoryProvider = Provider(
  (ref) => PatientsRepository(ref.watch(databaseProvider)),
);
final visitsRepositoryProvider = Provider(
  (ref) => VisitsRepository(ref.watch(databaseProvider)),
);
final draftsRepositoryProvider = Provider(
  (ref) => DraftsRepository(ref.watch(databaseProvider)),
);
final dangerSignsRepositoryProvider = Provider(
  (ref) => DangerSignsRepository(ref.watch(databaseProvider)),
);
final urgentRepositoryProvider = Provider(
  (ref) => UrgentRepository(ref.watch(databaseProvider)),
);

/// Live tables for the list screens and summaries.
final allPatientsProvider = StreamProvider(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).patients)
      .watch(),
);
final allVisitsProvider = StreamProvider(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).visits)
      .watch(),
);

final authServiceProvider = Provider((ref) => AuthService());

/// The signed-in CHW. Null while signed out.
final sessionProvider = StateProvider<Session?>((ref) => null);

/// Reachability. Slice 5 replaces this with the HEAD /health check and connectivity_plus.
final isOnlineProvider = StateProvider<bool>((ref) => true);
final allDispatchesProvider = StreamProvider(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).urgentDispatch)
      .watch(),
);
final dangerSignLabelsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.dangerSigns).get();
  return {for (final r in rows) r.code: r.labelEn};
});

/// One visit with its patient and ticked sign codes, for the urgent and saved screens.
final visitDetailProvider =
    FutureProvider.family<
      ({Visit visit, Patient patient, List<String> signs})?,
      String
    >((ref, id) async {
      ref.watch(allVisitsProvider); // refresh when the visit changes
      final visit = await ref.watch(visitsRepositoryProvider).get(id);
      if (visit == null) return null;
      final patient = await ref
          .watch(patientsRepositoryProvider)
          .get(visit.patientId);
      if (patient == null) return null;
      return (
        visit: visit,
        patient: patient,
        signs: await ref.watch(visitsRepositoryProvider).signCodes(id),
      );
    });

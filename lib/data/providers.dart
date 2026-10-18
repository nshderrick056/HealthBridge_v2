import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';
import 'repositories/danger_signs_repository.dart';
import 'repositories/drafts_repository.dart';
import 'repositories/patients_repository.dart';
import 'repositories/visits_repository.dart';

/// Must be overridden at startup with the opened database:
/// `ProviderScope(overrides: [databaseProvider.overrideWithValue(await openAppDatabase())], ...)`.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override databaseProvider'));

final patientsRepositoryProvider = Provider((ref) => PatientsRepository(ref.watch(databaseProvider)));
final visitsRepositoryProvider = Provider((ref) => VisitsRepository(ref.watch(databaseProvider)));
final draftsRepositoryProvider = Provider((ref) => DraftsRepository(ref.watch(databaseProvider)));
final dangerSignsRepositoryProvider = Provider((ref) => DangerSignsRepository(ref.watch(databaseProvider)));
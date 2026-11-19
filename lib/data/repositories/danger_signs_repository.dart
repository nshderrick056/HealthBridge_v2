import 'package:drift/drift.dart';

import '../db.dart';
import '../models.dart';

class DangerSignsRepository {
  DangerSignsRepository(this._db);

  final AppDatabase _db;

  Future<List<DangerSign>> forType(VisitType type) =>
      (_db.select(_db.dangerSigns)
            ..where((t) => t.visitType.equalsValue(type))
            ..orderBy([(t) => OrderingTerm.asc(t.code)]))
          .get();

  /// Replaces the list with the server's copy (called by the sync engine).
  Future<void> replaceAll(List<DangerSignsCompanion> signs) =>
      _db.transaction(() async {
        await _db.delete(_db.dangerSigns).go();
        await _db.batch((b) => b.insertAll(_db.dangerSigns, signs));
      });
}

import 'dart:convert';

import '../db.dart';

/// Autosave for half-filled forms: one draft per screen key, never synced.
class DraftsRepository {
  DraftsRepository(this._db, {DateTime Function()? now}) : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<void> save(String screen, Map<String, Object?> data) => _db.into(_db.drafts).insertOnConflictUpdate(
      DraftsCompanion.insert(id: screen, screen: screen, dataJson: jsonEncode(data), updatedAt: _now()));

  Future<Map<String, Object?>?> load(String screen) async {
    final row = await (_db.select(_db.drafts)..where((t) => t.id.equals(screen))).getSingleOrNull();
    return row == null ? null : Map<String, Object?>.from(jsonDecode(row.dataJson) as Map);
  }

  Future<void> delete(String screen) => (_db.delete(_db.drafts)..where((t) => t.id.equals(screen))).go();
}
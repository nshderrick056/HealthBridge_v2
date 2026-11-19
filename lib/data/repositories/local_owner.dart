import 'package:drift/drift.dart';

import '../db.dart';

/// The phone's records belong to another CHW and some have not uploaded yet.
class LocalDataInUse implements Exception {
  const LocalDataInUse();

  @override
  String toString() =>
      'This phone has records from another CHW that have not uploaded yet. '
      'That CHW should sign in and sync first.';
}

/// Keeps one CHW's records on the phone at a time. The encrypted database remembers whose they are
/// (`sync_meta.owner_uid`); a different CHW signing in starts from an empty database, so one person's
/// patients are never uploaded under another's account. Unsent records are never thrown away: while
/// the outbox holds any, only their owner can sign in.
class LocalOwner {
  LocalOwner(this._db);

  final AppDatabase _db;
  static const _key = 'owner_uid';

  /// Makes [userId] the owner, clearing another CHW's (fully uploaded) records first.
  /// Throws [LocalDataInUse] when another CHW still has records waiting to upload.
  Future<void> claim(String userId) => _db.transaction(() async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    final owner = row?.value;
    if (owner == userId) return;
    // A phone upgraded from before owners were recorded keeps its data for whoever signs in first.
    if (owner != null) {
      final unsent = await _db.select(_db.outbox).get();
      if (unsent.isNotEmpty) throw const LocalDataInUse();
      for (final TableInfo<Table, Object?> table in [
        _db.visitDangerSigns,
        _db.urgentDispatch,
        _db.visits,
        _db.patients,
        _db.drafts,
        _db.syncMeta,
      ]) {
        await _db.delete(table).go();
      }
    }
    await _db
        .into(_db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(key: _key, value: userId),
        );
  });
}

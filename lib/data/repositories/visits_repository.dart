import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../forms/danger_signs.dart';
import '../models.dart';

class VisitsRepository {
  VisitsRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  /// Saves a finished visit, its ticked danger signs and its outbox row in one transaction.
  /// `isUrgent` is derived from [signCodes] here, so the UI cannot get it out of step with the signs.
  Future<Visit> record({
    required String patientId,
    required VisitType type,
    Map<String, Object?> answers = const {},
    List<String> signCodes = const [],
    String? notes,
    DateTime? followUpOn,
    DateTime? recordedAt,
  }) {
    final id = _uuid.v4();
    final codes = signCodes.toSet().toList()..sort();
    return _db.transaction(() async {
      final visit = await _db
          .into(_db.visits)
          .insertReturning(
            VisitsCompanion.insert(
              id: id,
              shortCode: id.substring(0, 8),
              patientId: patientId,
              type: type,
              answersJson: Value(jsonEncode(answers)),
              notes: Value(notes),
              isUrgent: Value(isUrgent(codes)),
              followUpOn: Value(followUpOn),
              recordedAt: recordedAt ?? _now(),
              syncState: const Value(SyncState.queued),
            ),
          );
      await _db.batch(
        (b) => b.insertAll(_db.visitDangerSigns, [
          for (final c in codes)
            VisitDangerSignsCompanion.insert(visitId: id, code: c),
        ]),
      );
      await _db
          .into(_db.outbox)
          .insert(
            OutboxCompanion.insert(
              entity: 'visit',
              entityId: id,
              op: OutboxOp.upsert,
              payloadJson: jsonEncode(visitPayload(visit, codes)),
            ),
          );
      return visit;
    });
  }

  /// Puts a failed visit back in the queue (the sync engine picks it up on its next run).
  Future<void> retry(String id) => _db.transaction(() async {
    await (_db.update(_db.visits)..where((t) => t.id.equals(id))).write(
      const VisitsCompanion(syncState: Value(SyncState.queued)),
    );
    await (_db.update(
      _db.outbox,
    )..where((t) => t.entity.equals('visit') & t.entityId.equals(id))).write(
      const OutboxCompanion(
        attempts: Value(0),
        nextTryAt: Value(null),
        lastError: Value(null),
      ),
    );
  });

  Future<Visit?> get(String id) =>
      (_db.select(_db.visits)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Visit>> watchForPatient(String patientId) =>
      (_db.select(_db.visits)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
          .watch();

  Future<List<String>> signCodes(String visitId) async {
    final rows = await (_db.select(
      _db.visitDangerSigns,
    )..where((t) => t.visitId.equals(visitId))).get();
    return rows.map((r) => r.code).toList()..sort();
  }
}

/// The visit as /sync/push and POST /alerts take it.
Map<String, Object?> visitPayload(Visit v, List<String> signCodes) => {
  'id': v.id,
  'short_code': v.shortCode,
  'patient_id': v.patientId,
  'type': v.type.name,
  'answers': jsonDecode(v.answersJson),
  'notes': v.notes,
  'is_urgent': v.isUrgent,
  'follow_up_on': v.followUpOn?.toIso8601String(),
  'recorded_at': v.recordedAt.toUtc().toIso8601String(),
  'danger_signs': signCodes,
};

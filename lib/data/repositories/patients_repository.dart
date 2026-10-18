import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models.dart';

/// Every write puts the patient row and its outbox row in one transaction, so a record is never
/// saved without being queued for upload (or the other way round).
class PatientsRepository {
  PatientsRepository(this._db, {DateTime Function()? now}) : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  Future<Patient> create({
    required String fullName,
    required String village,
    String? sex,
    DateTime? birthDate,
    int? ageEstimate,
    String? phone,
    DateTime? consentAt,
  }) {
    final now = _now();
    final id = _uuid.v4();
    return _db.transaction(() async {
      final row = PatientsCompanion.insert(
        id: id,
        shortId: 'P${id.substring(0, 6).toUpperCase()}',
        fullName: fullName,
        village: village,
        sex: Value(sex),
        birthDate: Value(birthDate),
        ageEstimate: Value(ageEstimate),
        phone: Value(phone),
        consentAt: consentAt ?? now,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.queued),
      );
      final patient = await _db.into(_db.patients).insertReturning(row);
      await _enqueue(patient);
      return patient;
    });
  }

  Future<Patient> update(Patient p) {
    return _db.transaction(() async {
      final next = p.copyWith(updatedAt: _now(), syncState: SyncState.queued);
      await _db.update(_db.patients).replace(next);
      await _enqueue(next);
      return next;
    });
  }

  Future<Patient?> get(String id) =>
      (_db.select(_db.patients)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Live list for the patients tab; [query] matches name, short ID or village.
  Stream<List<Patient>> watch({String query = ''}) {
    final q = '%${query.trim()}%';
    return (_db.select(_db.patients)
          ..where((t) => t.fullName.like(q) | t.shortId.like(q) | t.village.like(q))
          ..orderBy([(t) => OrderingTerm.asc(t.fullName)]))
        .watch();
  }

  Future<void> _enqueue(Patient p) => _db.into(_db.outbox).insert(OutboxCompanion.insert(
        entity: 'patient',
        entityId: p.id,
        op: OutboxOp.upsert,
        payloadJson: jsonEncode({
          'id': p.id,
          'short_id': p.shortId,
          'full_name': p.fullName,
          'sex': p.sex,
          'birth_date': p.birthDate?.toIso8601String(),
          'age_estimate': p.ageEstimate,
          'village': p.village,
          'phone': p.phone,
          'consent_at': p.consentAt.toUtc().toIso8601String(),
          'created_at': p.createdAt.toUtc().toIso8601String(),
          'updated_at': p.updatedAt.toUtc().toIso8601String(),
        }),
      ));
}
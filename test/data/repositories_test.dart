import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/forms/danger_signs.dart';
import 'package:health_bridge/data/forms/validation.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/repositories/danger_signs_repository.dart';
import 'package:health_bridge/data/repositories/drafts_repository.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';
import 'package:health_bridge/data/repositories/visits_repository.dart';

void main() {
  late AppDatabase db;
  late PatientsRepository patients;
  late VisitsRepository visits;

  final clock = DateTime.utc(2026, 10, 6, 19, 14);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    patients = PatientsRepository(db, now: () => clock);
    visits = VisitsRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  Future<Patient> newPatient() =>
      patients.create(fullName: 'Test Patient', village: 'Demo Village');

  group('patients', () {
    test(
      'create saves the patient and queues exactly one outbox row',
      () async {
        final p = await newPatient();
        expect(p.syncState, SyncState.queued);
        expect(p.shortId, matches(RegExp(r'^P[0-9A-F]{6}$')));
        expect(
          p.createdAt.isAtSameMomentAs(clock),
          isTrue,
        ); // drift returns local time

        final box = await db.select(db.outbox).get();
        expect(box, hasLength(1));
        expect(box.single.entity, 'patient');
        expect(box.single.entityId, p.id);
        expect(box.single.op, OutboxOp.upsert);
        expect(
          jsonDecode(box.single.payloadJson),
          containsPair('short_id', p.shortId),
        );
      },
    );

    test('update bumps updatedAt and queues another change', () async {
      final p = await newPatient();
      final later = PatientsRepository(
        db,
        now: () => clock.add(const Duration(hours: 1)),
      );
      final next = await later.update(p.copyWith(village: 'Other Village'));
      expect(
        next.updatedAt.isAtSameMomentAs(clock.add(const Duration(hours: 1))),
        isTrue,
      );
      expect((await later.get(p.id))!.village, 'Other Village');
      expect(await db.select(db.outbox).get(), hasLength(2));
    });

    test('watch filters by name, short ID and village', () async {
      final p = await newPatient();
      await patients.create(fullName: 'Someone Else', village: 'Far Hill');
      expect(
        (await patients.watch(query: 'far').first).map((x) => x.fullName),
        ['Someone Else'],
      );
      expect((await patients.watch(query: p.shortId).first).map((x) => x.id), [
        p.id,
      ]);
      expect(await patients.watch().first, hasLength(2));
    });
  });

  group('visits', () {
    test(
      'an urgent visit gets its short code, signs and one outbox row',
      () async {
        final p = await newPatient();
        final v = await visits.record(
          patientId: p.id,
          type: VisitType.maternal,
          answers: {'temperature': 38.9, 'gestational_weeks': 32},
          signCodes: ['HB', 'CV', 'HB'],
        );
        expect(v.isUrgent, isTrue);
        expect(v.shortCode, v.id.substring(0, 8));
        expect(v.syncState, SyncState.queued);
        expect(await visits.signCodes(v.id), ['CV', 'HB']);

        final box = await (db.select(
          db.outbox,
        )..where((t) => t.entity.equals('visit'))).get();
        expect(box, hasLength(1));
        final payload =
            jsonDecode(box.single.payloadJson) as Map<String, dynamic>;
        expect(payload['danger_signs'], ['CV', 'HB']);
        expect(payload['answers'], containsPair('temperature', 38.9));
        expect(payload['recorded_at'], '2026-10-06T19:14:00.000Z');
      },
    );

    test('no signs means not urgent', () async {
      final p = await newPatient();
      final v = await visits.record(patientId: p.id, type: VisitType.child);
      expect(v.isUrgent, isFalse);
      expect(await visits.signCodes(v.id), isEmpty);
    });

    test('a failed save rolls back the visit, its signs and its outbox row together', () async {
      await newPatient();
      final before = (await db.select(db.outbox).get()).length;
      await expectLater(
        visits.record(
          patientId: 'no-such-patient',
          type: VisitType.malaria,
          signCodes: ['LT'],
        ),
        throwsA(anything),
      );
      expect(await db.select(db.visits).get(), isEmpty);
      expect(await db.select(db.visitDangerSigns).get(), isEmpty);
      expect(await db.select(db.outbox).get(), hasLength(before));
    });

    test('watchForPatient lists newest first', () async {
      final p = await newPatient();
      final old = await visits.record(
        patientId: p.id,
        type: VisitType.child,
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      final recent = await visits.record(
        patientId: p.id,
        type: VisitType.child,
      );
      expect((await visits.watchForPatient(p.id).first).map((v) => v.id), [
        recent.id,
        old.id,
      ]);
    });
  });

  group('drafts', () {
    test('save overwrites, load reads back, delete removes', () async {
      final drafts = DraftsRepository(db, now: () => clock);
      expect(await drafts.load('visit.maternal'), isNull);
      await drafts.save('visit.maternal', {'temperature': 37.5});
      await drafts.save('visit.maternal', {'temperature': 38.0, 'notes': 'x'});
      expect(await drafts.load('visit.maternal'), {
        'temperature': 38.0,
        'notes': 'x',
      });
      expect(await db.select(db.drafts).get(), hasLength(1));
      await drafts.delete('visit.maternal');
      expect(await drafts.load('visit.maternal'), isNull);
    });
  });

  group('danger signs', () {
    test('are seeded on first open and filtered by visit type', () async {
      final repo = DangerSignsRepository(db);
      expect((await repo.forType(VisitType.maternal)).map((s) => s.code), [
        'CV',
        'HB',
        'SH',
      ]);
      expect(
        await db.select(db.dangerSigns).get(),
        hasLength(seedDangerSigns.length),
      );
    });

    test('replaceAll swaps in the server list', () async {
      final repo = DangerSignsRepository(db);
      await repo.replaceAll([
        DangerSignsCompanion.insert(
          code: 'ZZ',
          visitType: VisitType.child,
          labelEn: 'Test',
          labelRw: 'Test',
        ),
      ]);
      expect((await db.select(db.dangerSigns).get()).map((s) => s.code), [
        'ZZ',
      ]);
    });
  });

  group('form rules', () {
    test('isUrgent is true for any ticked sign', () {
      expect(isUrgent([]), isFalse);
      expect(isUrgent(['MR']), isTrue);
    });

    test(
      'ranges accept the edges and reject outside values with a message',
      () {
        expect(temperatureC.check(38.9), isNull);
        expect(temperatureC.check(30), isNull);
        expect(temperatureC.check(45.1), contains('30.0 to 45.0'));
        expect(muacMm.check(null), 'Required');
        expect(gestationalWeeks.check(0), isNotNull);
        expect(gestationalWeeks.check(45), isNull);
      },
    );
  });
}

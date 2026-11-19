import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';
import 'package:health_bridge/data/repositories/visits_repository.dart';
import 'package:health_bridge/domain/entities/enums.dart';
import 'package:health_bridge/domain/usecases/patient_use_cases.dart';
import 'package:health_bridge/domain/usecases/record_visit.dart';

void main() {
  late AppDatabase db;
  late PatientsRepository patients;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    patients = PatientsRepository(db);
  });
  tearDown(() => db.close());

  group('SavePatient', () {
    test('cleans the form text when registering', () async {
      final p = await SavePatient(patients)(
        fullName: '  Uwase Marie ',
        village: ' Nyamata',
        sex: 'F',
        age: ' 32 ',
        phone: '   ',
      );
      expect(p.fullName, 'Uwase Marie');
      expect(p.village, 'Nyamata');
      expect(p.ageEstimate, 32);
      expect(p.phone, isNull);
    });

    test('edits the given patient instead of creating one', () async {
      final save = SavePatient(patients);
      final p = await save(fullName: 'Uwase Marie', village: 'Nyamata');
      await save(
        editing: p,
        fullName: 'Uwase Marie-Claire',
        village: 'Nyamata',
        age: 'not a number',
        phone: '+250780000200',
      );
      final rows = await db.select(db.patients).get();
      expect(rows, hasLength(1));
      expect(rows.single.fullName, 'Uwase Marie-Claire');
      expect(rows.single.ageEstimate, isNull);
      expect(rows.single.phone, '+250780000200');
    });
  });

  test('ArchivePatient keeps the record and can be undone', () async {
    final archive = ArchivePatient(patients);
    final p = await SavePatient(patients)(fullName: 'A', village: 'B');
    final archived = await archive(p);
    expect(archived.archivedAt, isNotNull);
    expect(await patients.get(p.id), isNotNull);
    expect((await archive.undo(archived)).archivedAt, isNull);
  });

  test(
    'RecordVisit stores empty notes as none and is urgent with signs',
    () async {
      final p = await SavePatient(patients)(fullName: 'A', village: 'B');
      final record = RecordVisit(VisitsRepository(db));
      final calm = await record(
        patientId: p.id,
        type: VisitType.child,
        answers: const {},
        signCodes: const [],
        notes: '   ',
      );
      expect(calm.notes, isNull);
      expect(calm.isUrgent, isFalse);
      final urgent = await record(
        patientId: p.id,
        type: VisitType.maternal,
        answers: const {},
        signCodes: {'HB'},
        notes: ' bleeding ',
      );
      expect(urgent.notes, 'bleeding');
      expect(urgent.isUrgent, isTrue);
    },
  );
}

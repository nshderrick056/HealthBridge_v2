import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/repositories/local_owner.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> patients() async => (await db.select(db.patients).get()).length;

  test(
    'the first CHW keeps what is on the phone (an upgraded install)',
    () async {
      await PatientsRepository(db).create(fullName: 'A', village: 'B');
      await LocalOwner(db).claim('chw-1');
      expect(await patients(), 1);
    },
  );

  test('a different CHW starts empty once everything has uploaded', () async {
    await LocalOwner(db).claim('chw-1');
    await PatientsRepository(db).create(fullName: 'A', village: 'B');
    await db.delete(db.outbox).go(); // as if synced
    await LocalOwner(db).claim('chw-2');
    expect(await patients(), 0);
    // And chw-2 is now the owner: signing in again keeps their records.
    await PatientsRepository(db).create(fullName: 'C', village: 'D');
    await LocalOwner(db).claim('chw-2');
    expect(await patients(), 1);
  });

  test(
    'records still waiting to upload block another CHW and are kept',
    () async {
      await LocalOwner(db).claim('chw-1');
      await PatientsRepository(db).create(fullName: 'A', village: 'B');
      expect(LocalOwner(db).claim('chw-2'), throwsA(isA<LocalDataInUse>()));
      await Future<void>.delayed(Duration.zero);
      expect(await patients(), 1);
      await LocalOwner(db).claim('chw-1'); // the owner can still sign in
    },
  );
}

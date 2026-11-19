import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';
import 'package:health_bridge/data/repositories/visits_repository.dart';
import 'package:health_bridge/sync/background_sync.dart';
import 'package:health_bridge/sync/sync_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A stand-in for the HealthBridge API (health check, device registration, SMS-case merge).
class FakeApi {
  bool up = true;
  String validToken = 'token-1';
  int registrations = 0;
  final merges = <String>[];

  late final client = MockClient((req) async {
    if (!up) throw http.ClientException('no network');
    final path = req.url.path;
    if (path == '/health') return http.Response('{"ok":true}', 200);
    if (req.headers['authorization'] != 'Bearer $validToken') {
      return http.Response('{"error":"unauthorized"}', 401);
    }
    if (path == '/devices/register') {
      registrations++;
      return http.Response(
        jsonEncode({
          'deviceId': 'D000042',
          'smsKey': base64.encode(List.filled(32, 7)),
        }),
        201,
      );
    }
    final merge = RegExp(r'^/visits/([^/]+)/merge-sms$').firstMatch(path);
    if (merge != null) {
      merges.add(merge[1]!);
      return http.Response('{"merged":true}', 200);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  late AppDatabase db;
  late FakeApi api;
  late FakeFirebaseFirestore fs;
  late SyncEngine engine;
  late DateTime clock;
  late Session session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    api = FakeApi();
    fs = FakeFirebaseFirestore();
    clock = DateTime.utc(2026, 10, 6, 19, 14);
    session = const Session(
      accessToken: 'token-1',
      userId: 'u1',
      fullName: 'Test CHW',
      healthCenterId: 'hc-1',
    );
    engine = SyncEngine(
      db: db,
      auth: AuthService(client: api.client, baseUrl: 'http://api.test'),
      session: () => session,
      onSession: (s) => session = s,
      firestore: fs,
      client: api.client,
      now: () => clock,
    );
  });
  tearDown(() => db.close());

  Future<(Patient, Visit)> recordOne({List<String> signs = const []}) async {
    final p = await PatientsRepository(
      db,
      now: () => clock,
    ).create(fullName: 'Uwase Marie', village: 'Nyamata', ageEstimate: 32);
    final v = await VisitsRepository(db, now: () => clock).record(
      patientId: p.id,
      type: VisitType.maternal,
      answers: {'general_condition': 'Stable'},
      signCodes: signs,
    );
    return (p, v);
  }

  test('back-off is 30 s, 2 min, 10 min, then every 30 min', () {
    expect(backoff(1), const Duration(seconds: 30));
    expect(backoff(2), const Duration(minutes: 2));
    expect(backoff(3), const Duration(minutes: 10));
    expect(backoff(7), const Duration(minutes: 30));
  });

  test('pushes the patient and visit to Firestore with their owner, marks both synced and empties the outbox', () async {
    final (p, v) = await recordOne(signs: ['HB']);
    final report = await engine.run();

    expect(report.online, isTrue);
    expect(report.pushed, 2);
    final patient = (await fs.collection('patients').doc(p.id).get()).data()!;
    expect(patient, containsPair('fullName', 'Uwase Marie'));
    expect(patient, containsPair('chwId', 'u1'));
    expect(patient, containsPair('healthCenterId', 'hc-1'));
    expect(patient['createdAt'], isA<Timestamp>());
    final visit = (await fs.collection('visits').doc(v.id).get()).data()!;
    expect(visit, containsPair('patientId', p.id));
    expect(visit, containsPair('deviceId', 'D000042'));
    expect(visit, containsPair('isUrgent', true));
    expect(visit, containsPair('dangerSigns', ['HB']));
    expect(visit, containsPair('source', 'app'));

    expect(await db.select(db.outbox).get(), isEmpty);
    expect(
      (await db.select(db.patients).getSingle()).syncState,
      SyncState.synced,
    );
    expect(
      (await db.select(db.visits).getSingle()).syncState,
      SyncState.synced,
    );
    expect(api.registrations, 1);
  });

  test('an edit and an archive overwrite the same document', () async {
    final (p, _) = await recordOne();
    await engine.run();
    final repo = PatientsRepository(db, now: () => clock);
    clock = clock.add(const Duration(minutes: 1));
    await repo.archive((await repo.get(p.id))!);
    await engine.run();
    final doc = (await fs.collection('patients').doc(p.id).get()).data()!;
    expect(doc['archivedAt'], isA<Timestamp>());
    expect((await fs.collection('patients').get()).docs, hasLength(1));
  });

  test("pull adds the CHW's patients (not SMS stubs), confirms urgent alerts, refreshes danger signs and the call number", () async {
    final (_, v) = await recordOne(signs: ['HB']);
    await db
        .into(db.urgentDispatch)
        .insert(
          UrgentDispatchCompanion.insert(
            visitId: v.id,
            channel: 'sms_direct',
            state: DispatchState.sentSms,
            sentAt: Value(clock),
          ),
        );
    final at = Timestamp.fromDate(clock);
    await fs.collection('patients').doc('p-remote').set({
      'shortId': 'P0R0R0',
      'chwId': 'u1',
      'healthCenterId': 'hc-1',
      'fullName': 'Mukamana Claudine',
      'village': 'Gatare',
      'consentAt': at,
      'createdAt': at,
      'updatedAt': at,
    });
    await fs.collection('patients').doc('p-stub').set({
      'shortId': 'P0S0S0',
      'chwId': 'u1',
      'fullName': '(awaiting sync)',
      'updatedAt': at,
    });
    await fs.collection('patients').doc('p-other').set({
      'shortId': 'P0T0T0',
      'chwId': 'someone-else',
      'fullName': 'Not mine',
      'updatedAt': at,
    });
    await fs.collection('alerts').doc(v.id).set({
      'visitId': v.id,
      'chwId': 'u1',
      'status': 'new',
    });
    await fs.collection('dangerSigns').doc('XX').set({
      'visitType': 'child',
      'labelEn': 'New sign',
      'labelRw': '',
    });
    await fs.collection('healthCenters').doc('hc-1').set({
      'callNumber': '+250780009999',
    });

    await engine.run();

    final names = (await db.select(db.patients).get())
        .map((p) => p.fullName)
        .toSet();
    expect(names, {'Uwase Marie', 'Mukamana Claudine'});
    final d = await db.select(db.urgentDispatch).getSingle();
    expect(d.state, DispatchState.confirmed);
    expect((await db.select(db.dangerSigns).get()).map((s) => s.code), ['XX']);
    final call = await (db.select(
      db.syncMeta,
    )..where((t) => t.key.equals('call_number'))).getSingle();
    expect(call.value, '+250780009999');
  });

  test(
    'an urgent visit that also went by SMS is merged on the server once',
    () async {
      final (_, v) = await recordOne(signs: ['HB']);
      await db
          .into(db.urgentDispatch)
          .insert(
            UrgentDispatchCompanion.insert(
              visitId: v.id,
              channel: 'sms_direct',
              state: DispatchState.sentSms,
              sentAt: Value(clock),
            ),
          );
      await engine.run();
      await engine.run();
      expect(api.merges, [v.id]);
    },
  );

  test('offline: nothing is written and the report says so', () async {
    await recordOne();
    api.up = false;
    final report = await engine.run();
    expect(report.online, isFalse);
    expect((await fs.collection('patients').get()).docs, isEmpty);
    expect(await db.select(db.outbox).get(), hasLength(2));
  });

  test('without a session it does nothing', () async {
    final signedOut = SyncEngine(
      db: db,
      auth: AuthService(client: api.client, baseUrl: 'http://api.test'),
      session: () => null,
      onSession: (_) {},
      firestore: fs,
      client: api.client,
    );
    expect((await signedOut.run()).online, isNull);
  });

  test('two runs at once share one push', () async {
    await recordOne();
    final results = await Future.wait([engine.run(), engine.run()]);
    expect(results.map((r) => r.pushed), [2, 2]);
    expect((await fs.collection('patients').get()).docs, hasLength(1));
  });

  test('an expired token is refreshed once and the call repeated', () async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', displayName: 'Test CHW'),
    );
    api.validToken = 'never-matches-the-old-one';
    final refreshing = SyncEngine(
      db: db,
      auth: AuthService(
        auth: auth,
        client: api.client,
        baseUrl: 'http://api.test',
      ),
      session: () => session,
      onSession: (s) {
        session = s;
        api.validToken = s.accessToken;
      },
      firestore: fs,
      client: api.client,
    );
    final res = await refreshing.send('POST', '/devices/register');
    expect(res.statusCode, 201);
    expect(session.accessToken, isNot('token-1'));
  });

  test('background run while signed out opens nothing', () async {
    final ok = await backgroundSync(
      auth: AuthService(
        auth: MockFirebaseAuth(),
        client: api.client,
        baseUrl: 'http://api.test',
      ),
      openDb: () => throw StateError('must not open the database'),
    );
    expect(ok, isTrue);
  });
}

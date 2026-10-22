import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';
import 'package:health_bridge/data/repositories/visits_repository.dart';
import 'package:health_bridge/sync/sync_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A stand-in for the API: records what the engine sends and answers as each test configures it.
class FakeServer {
  bool up = true;
  int pushStatus = 200;
  Set<String> rejectEntities = {};
  String validToken = 'access-1';
  Map<String, dynamic> pullBody = {
    'serverTime': '2026-10-06T20:00:00.000Z',
    'patients': [],
    'alerts': [],
    'dangerSigns': [],
  };
  final pushes = <Map<String, dynamic>>[];
  final pulls = <Uri>[];
  int registrations = 0;
  int refreshes = 0;

  late final client = MockClient((req) async {
    if (!up) throw http.ClientException('no network');
    final path = req.url.path;
    if (path == '/health') return http.Response('{"ok":true}', 200);
    if (path == '/auth/refresh') {
      refreshes++;
      validToken = 'access-2';
      return http.Response(jsonEncode({'accessToken': validToken}), 200);
    }
    if (req.headers['authorization'] != 'Bearer $validToken') {
      return http.Response('{"error":"unauthorized"}', 401);
    }
    switch (path) {
      case '/devices/register':
        registrations++;
        return http.Response(
          jsonEncode({
            'deviceId': 'D000042',
            'smsKey': base64.encode(List.filled(32, 7)),
          }),
          201,
        );
      case '/sync/push':
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        pushes.add(body);
        if (pushStatus != 200) {
          return http.Response('{"error":"internal_error"}', pushStatus);
        }
        return http.Response(
          jsonEncode({
            'results': [
              for (final c
                  in (body['changes'] as List).cast<Map<String, dynamic>>())
                rejectEntities.contains(c['entity'])
                    ? {'seq': c['seq'], 'ok': false, 'error': 'unknown_patient'}
                    : {'seq': c['seq'], 'ok': true},
            ],
          }),
          200,
        );
      case '/sync/pull':
        pulls.add(req.url);
        return http.Response(jsonEncode(pullBody), 200);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  late AppDatabase db;
  late FakeServer server;
  late SyncEngine engine;
  late DateTime clock;
  late Session session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    clock = DateTime.utc(2026, 10, 6, 19, 14);
    session = const Session(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      userId: 'u1',
      fullName: 'Test CHW',
    );
    engine = SyncEngine(
      db: db,
      auth: AuthService(client: server.client, baseUrl: 'http://api.test'),
      session: () => session,
      onSession: (s) => session = s,
      client: server.client,
      now: () => clock,
    );
  });
  tearDown(() => db.close());

  Future<(Patient, Visit)> recordOne() async {
    final p = await PatientsRepository(db)
        .create(fullName: 'Uwase Marie', village: 'Nyamata');
    final v = await VisitsRepository(db)
        .record(patientId: p.id, type: VisitType.maternal, signCodes: ['HB']);
    return (p, v);
  }

  test('back-off is 30 s, 2 min, 10 min, then every 30 min', () {
    expect(
      [for (var i = 1; i <= 5; i++) backoff(i).inSeconds],
      [30, 120, 600, 1800, 1800],
    );
  });

  test('pushes patient then visit in order, marks both synced and empties the outbox', () async {
    final (p, v) = await recordOne();

    final report = await engine.run();
    expect(report.online, isTrue);
    expect(report.pushed, 2);
    expect(server.pushes, hasLength(1));
    final changes = (server.pushes.single['changes'] as List)
        .cast<Map<String, dynamic>>();
    expect(server.pushes.single['deviceId'], 'D000042');
    expect(changes.map((c) => c['entity']), ['patient', 'visit']);
    expect((changes[1]['payload'] as Map)['danger_signs'], ['HB']);

    expect(await db.select(db.outbox).get(), isEmpty);
    expect(
      (await PatientsRepository(db).get(p.id))!.syncState,
      SyncState.synced,
    );
    expect((await VisitsRepository(db).get(v.id))!.syncState, SyncState.synced);

    // A second run has nothing to push and does not register the device again.
    await engine.run();
    expect(server.pushes, hasLength(1));
    expect(server.registrations, 1);
    expect(server.pulls, hasLength(2));
  });

  test(
    'a failed push keeps every row, backs off 30 s, and retries only once due',
    () async {
      final (p, _) = await recordOne();
      server.pushStatus = 500;

      final report = await engine.run();
      expect(report.error, isNotNull);
      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(2));
      expect(
        rows.every(
          (r) =>
              r.attempts == 1 &&
              r.nextTryAt!.isAtSameMomentAs(
                clock.add(const Duration(seconds: 30)),
              ),
        ),
        isTrue,
      );
      expect(
        (await PatientsRepository(db).get(p.id))!.syncState,
        SyncState.queued,
      ); // still pending, not failed

      server.pushStatus = 200;
      await engine.run();
      expect(server.pushes, hasLength(1), reason: 'not due yet');

      clock = clock.add(const Duration(seconds: 31));
      await engine.run();
      expect(server.pushes, hasLength(2));
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test(
    'a refused change is marked failed and kept for retry; the rest sync',
    () async {
      final (p, v) = await recordOne();
      server.rejectEntities = {'visit'};

      final report = await engine.run();
      expect(report.rejected, 1);
      expect(
        (await PatientsRepository(db).get(p.id))!.syncState,
        SyncState.synced,
      );
      expect(
        (await VisitsRepository(db).get(v.id))!.syncState,
        SyncState.failed,
      );
      final left = await db.select(db.outbox).get();
      expect(left.single.entityId, v.id);
      expect(left.single.lastError, 'unknown_patient');
    },
  );

  test(
    'an expired access token is refreshed once and the request repeated',
    () async {
      await recordOne();
      server.validToken = 'access-2'; // the token the engine holds is now stale

      final report = await engine.run();
      expect(report.pushed, 2);
      expect(server.refreshes, 1);
      expect(session.accessToken, 'access-2');
    },
  );

  test('pull adds server patients, confirms urgent alerts, refreshes danger signs and remembers the time', () async {
    final (_, v) = await recordOne();
    await db
        .into(db.urgentDispatch)
        .insert(
          UrgentDispatchCompanion.insert(
            visitId: v.id,
            channel: 'sms_composer',
            state: DispatchState.sentSms,
          ),
        );
    server.pullBody = {
      'serverTime': '2026-10-06T20:00:00.000Z',
      'patients': [
        {
          'id': '6f1c2b3a-0000-4000-8000-000000000001',
          'short_id': 'P6F1C2B',
          'full_name': 'From Other Phone',
          'sex': 'M',
          'birth_date': null,
          'age_estimate': 40,
          'village': 'Gatare',
          'phone': null,
          'consent_at': '2026-10-01T08:00:00.000Z',
          'created_at': '2026-10-01T08:00:00.000Z',
          'updated_at': '2026-10-01T08:00:00.000Z',
        },
      ],
      'alerts': [
        {'visit_id': v.id, 'status': 'new', 'acked_to_chw_at': null},
      ],
      'dangerSigns': [
        {
          'code': 'HB',
          'visit_type': 'maternal',
          'label_en': 'Heavy bleeding (server)',
          'label_rw': 'Kuva amaraso menshi',
        },
      ],
    };

    await engine.run();

    final pulled = await PatientsRepository(db)
        .get('6f1c2b3a-0000-4000-8000-000000000001');
    expect(pulled!.fullName, 'From Other Phone');
    expect(pulled.syncState, SyncState.synced);
    final dispatch = await (db.select(
      db.urgentDispatch,
    )..where((t) => t.visitId.equals(v.id))).getSingle();
    expect(dispatch.state, DispatchState.confirmed);
    expect((await db.select(db.dangerSigns).get()).map((s) => s.labelEn), [
      'Heavy bleeding (server)',
    ]);

    await engine.run();
    expect(
      server.pulls.last.queryParameters['since'],
      '2026-10-06T20:00:00.000Z',
    );
  });

  test(
    'pull never overwrites a local edit that is still waiting to upload',
    () async {
      final (p, _) = await recordOne();
      server.pushStatus = 500;
      await engine
          .run(); // push fails: the rows back off and the patient stays queued
      server.pullBody = {
        ...server.pullBody,
        'patients': [
          {
            'id': p.id,
            'short_id': p.shortId,
            'full_name': 'Older Server Copy',
            'sex': null,
            'birth_date': null,
            'age_estimate': null,
            'village': 'Nyamata',
            'phone': null,
            'consent_at': '2026-10-01T08:00:00.000Z',
            'created_at': '2026-10-01T08:00:00.000Z',
            'updated_at': '2027-01-01T00:00:00.000Z',
          },
        ],
      };
      await engine
          .run(); // nothing is due yet, so this run goes straight to the pull
      expect(server.pulls, hasLength(1));
      expect((await PatientsRepository(db).get(p.id))!.fullName, 'Uwase Marie');
    },
  );

  test('offline: nothing is sent and the report says so', () async {
    await recordOne();
    server.up = false;

    final report = await engine.run();
    expect(report.online, isFalse);
    expect(server.pushes, isEmpty);
    final rows = await db.select(db.outbox).get();
    expect(
      rows.every((r) => r.attempts == 0),
      isTrue,
      reason: 'being offline is not a failed attempt',
    );
  });

  test('without a session it does nothing', () async {
    final idle = SyncEngine(
      db: db,
      auth: AuthService(client: server.client),
      session: () => null,
      onSession: (_) {},
      client: server.client,
    );
    expect((await idle.run()).online, isNull);
    expect(server.pushes, isEmpty);
  });

  test('two runs at once share one push', () async {
    await recordOne();
    await Future.wait([engine.run(), engine.run()]);
    expect(server.pushes, hasLength(1));
    expect(server.registrations, 1);
  });
}

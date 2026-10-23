import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/core/sms/codec.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/repositories/patients_repository.dart';
import 'package:health_bridge/data/repositories/visits_repository.dart';
import 'package:health_bridge/sync/sync_engine.dart';
import 'package:health_bridge/urgent/urgent_dispatcher.dart';
import 'package:health_bridge/urgent/urgent_sender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

enum Net { up, down, hang, error }

class FakeSender extends UrgentSender {
  bool fail = false;
  final sent = <(String, List<String>)>[];
  List<String> acks = [];

  @override
  String get channel => 'sms_direct';

  @override
  bool get readsAcks => true;

  @override
  Future<void> send(String to, List<String> parts) async {
    if (fail) throw const UrgentSendException('radio off');
    sent.add((to, parts));
  }

  @override
  Future<List<String>> takeAcks() async {
    final taken = acks;
    acks = [];
    return taken;
  }
}

void main() {
  final key = List<int>.filled(32, 7);
  late AppDatabase db;
  late FakeSender sender;
  late UrgentDispatcher dispatcher;
  late DateTime clock;
  late Net net;
  late List<Map<String, dynamic>> alertPosts;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'device': jsonEncode({
        'userId': 'u1',
        'deviceId': 'D000042',
        'smsKey': base64.encode(key),
      }),
    });
    db = AppDatabase(NativeDatabase.memory());
    sender = FakeSender();
    clock = DateTime.utc(2026, 10, 6, 19, 14);
    net = Net.up;
    alertPosts = [];
    final client = MockClient((req) async {
      switch (net) {
        case Net.down:
          throw http.ClientException('no network');
        case Net.hang:
          return Completer<http.Response>().future;
        case Net.error:
          return http.Response('{"error":"internal_error"}', 500);
        case Net.up:
          alertPosts.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response('{"alert":{"status":"new"}}', 200);
      }
    });
    const session = Session(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      userId: 'u1',
      fullName: 'Test CHW',
    );
    dispatcher = UrgentDispatcher(
      db: db,
      engine: SyncEngine(
        db: db,
        auth: AuthService(client: client, baseUrl: 'http://api.test'),
        session: () => session,
        onSession: (_) {},
        client: client,
      ),
      sender: sender,
      gatewayNumber: '+250780000500',
      internetTimeout: const Duration(milliseconds: 100),
      now: () => clock,
    );
  });
  tearDown(() => db.close());

  Future<(Patient, Visit)> urgentVisit() async {
    final p = await PatientsRepository(
      db,
    ).create(fullName: 'Uwase Marie', village: 'Nyamata');
    final v = await VisitsRepository(db, now: () => clock).record(
      patientId: p.id,
      type: VisitType.maternal,
      answers: {'temperature': 38.9, 'general_condition': 'Unstable'},
      signCodes: ['HB'],
    );
    return (p, v);
  }

  Future<UrgentDispatchData> dispatchOf(String visitId) => (db.select(
    db.urgentDispatch,
  )..where((t) => t.visitId.equals(visitId))).getSingle();

  test('waits 10 s for the internet and 10 minutes for the ack by default', () {
    final d = UrgentDispatcher(
      db: db,
      engine: dispatcher.engine,
      sender: sender,
    );
    expect(d.internetTimeout, const Duration(seconds: 10));
    expect(d.ackTimeout, const Duration(minutes: 10));
  });

  test('phone time is YYMMDDHHmm in Rwanda time (UTC+2)', () {
    expect(phoneTime(DateTime.utc(2026, 10, 6, 19, 14)), '2610062114');
    expect(phoneTime(DateTime.utc(2026, 12, 31, 23, 5)), '2701010105');
  });

  test('online: POST /alerts confirms it and no SMS is sent', () async {
    final (p, v) = await urgentVisit();
    await dispatcher.send(v.id);

    final d = await dispatchOf(v.id);
    expect(d.state, DispatchState.confirmed);
    expect(d.channel, 'internet');
    expect(d.confirmedAt, isNotNull);
    expect(sender.sent, isEmpty);
    final body = alertPosts.single;
    expect(body['deviceId'], 'D000042');
    expect(body['visit'], containsPair('id', v.id));
    expect(body['visit'], containsPair('is_urgent', true));
    expect(body['visit'], containsPair('danger_signs', ['HB']));
    expect(body['patient'], containsPair('id', p.id));
  });

  for (final failure in [Net.down, Net.error, Net.hang]) {
    test('internet ${failure.name}: the sealed SMS goes to the gateway, then waits for the ack', () async {
      net = failure;
      final (p, v) = await urgentVisit();
      await dispatcher.send(v.id);

      final d = await dispatchOf(v.id);
      expect(d.state, DispatchState.sentSms);
      expect(d.channel, 'sms_direct');
      final (to, parts) = sender.sent.single;
      expect(to, '+250780000500');
      expect(parts.single, startsWith('HB1 D000042 '));

      final fields = decodePlaintext((await openSms(key, parts)).plaintext);
      expect(fields.shortCode, v.shortCode);
      expect(fields.patient, p.shortId);
      expect(fields.type, 'M');
      expect(fields.time, '2610062114');
      expect(fields.signs, ['HB']);
      expect(fields.vitals, ['T389']);
    });
  }

  test('no ack within 10 minutes makes it unconfirmed; a later ack still confirms it', () async {
    net = Net.down;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);

    clock = clock.add(const Duration(minutes: 9, seconds: 59));
    expect(await dispatcher.expire(), 0);
    expect((await dispatchOf(v.id)).state, DispatchState.sentSms);

    clock = clock.add(const Duration(seconds: 1));
    expect(await dispatcher.expire(), 1);
    expect((await dispatchOf(v.id)).state, DispatchState.unconfirmed);

    expect(await dispatcher.acknowledge('00000000'), isNull);
    expect(await dispatcher.acknowledge(v.shortCode), v.id);
    expect((await dispatchOf(v.id)).state, DispatchState.confirmed);
    expect(await dispatcher.expire(), 0);
  });

  test('acks the receiver collected while the app was closed are applied', () async {
    net = Net.down;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);
    sender.acks = [v.shortCode];
    await dispatcher.applyAcks();
    expect((await dispatchOf(v.id)).state, DispatchState.confirmed);
  });

  test('Resend sends again and restarts the 10-minute wait', () async {
    net = Net.down;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);
    clock = clock.add(const Duration(minutes: 10));
    await dispatcher.expire();

    await dispatcher.sendSms(v.id);
    final d = await dispatchOf(v.id);
    expect(d.state, DispatchState.sentSms);
    expect(d.sentAt!.isAtSameMomentAs(clock), isTrue);
    expect(sender.sent, hasLength(2));
    expect(await dispatcher.expire(), 0);
  });

  test('an SMS that cannot be handed over is unconfirmed at once', () async {
    net = Net.down;
    sender.fail = true;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);
    expect((await dispatchOf(v.id)).state, DispatchState.unconfirmed);
  });

  test('without a registered device there is no key to seal with: unconfirmed', () async {
    FlutterSecureStorage.setMockInitialValues({});
    net = Net.down;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);
    expect((await dispatchOf(v.id)).state, DispatchState.unconfirmed);
    expect(sender.sent, isEmpty);
  });

  test('"I got the confirmation" (store build) confirms it', () async {
    net = Net.down;
    final (_, v) = await urgentVisit();
    await dispatcher.send(v.id);
    await dispatcher.confirm(v.id);
    expect((await dispatchOf(v.id)).state, DispatchState.confirmed);
  });
}

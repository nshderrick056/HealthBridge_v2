import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/sms/codec.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/repositories/patients_repository.dart';
import '../data/repositories/urgent_repository.dart';
import '../data/repositories/visits_repository.dart';
import '../sync/sync_engine.dart';
import 'urgent_sender.dart';

const _typeLetters = {
  VisitType.maternal: 'M',
  VisitType.child: 'C',
  VisitType.malaria: 'L',
  VisitType.nutrition: 'N',
};

/// YYMMDDHHmm in Rwanda time (UTC+2, no DST), which is how the server reads the SMS time field.
String phoneTime(DateTime t) {
  final r = t.toUtc().add(const Duration(hours: 2));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(r.year % 100)}${two(r.month)}${two(r.day)}${two(r.hour)}${two(r.minute)}';
}

/// What goes into the SMS (Backend Schema §3): short IDs and codes only, never a name.
AlertFields alertFields(Visit v, Patient p, List<String> signs) {
  final answers = jsonDecode(v.answersJson) as Map<String, dynamic>;
  final t = (answers['temperature'] as num?)?.toDouble();
  return AlertFields(
    shortCode: v.shortCode,
    patient: p.shortId,
    type: _typeLetters[v.type]!,
    time: phoneTime(v.recordedAt),
    signs: signs,
    vitals: [if (t != null && t > 0) 'T${(t * 10).round()}'],
  );
}

/// The urgent pathway (TRD §5): POST /alerts first, the SMS fallback when that fails or is slow,
/// then wait for the ack. States: sending -> sentSms -> confirmed | unconfirmed. An internet alert
/// goes straight to confirmed, because the server only answers once the alert is stored.
class UrgentDispatcher {
  UrgentDispatcher({
    required this.db,
    required this.engine,
    required this.sender,
    this.gatewayNumber = smsGatewayNumber,
    this.internetTimeout = const Duration(seconds: 10),
    this.ackTimeout = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _repo = UrgentRepository(db, now: now),
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final SyncEngine engine;
  final UrgentSender sender;
  final String gatewayNumber;
  final Duration internetTimeout;

  /// No ack after this long and the CHW is offered Resend and Call.
  final Duration ackTimeout;
  final UrgentRepository _repo;
  final DateTime Function() _now;

  /// "Send urgent alert".
  Future<void> send(String visitId) async {
    await _repo.start(visitId);
    try {
      await _postAlert(visitId).timeout(internetTimeout);
      await _repo.setState(visitId, DispatchState.confirmed);
    } on Exception {
      await sendSms(visitId);
    }
  }

  /// The SMS fallback, and the Resend button. Any failure to hand the SMS over leaves the alert
  /// unconfirmed straight away, so the CHW can call instead of waiting 10 minutes.
  Future<void> sendSms(String visitId) async {
    await _repo.setState(
      visitId,
      DispatchState.sending,
      channel: sender.channel,
    );
    try {
      final device = await engine.savedDevice();
      if (device == null) {
        throw const UrgentSendException('device not registered yet');
      }
      final (visit, patient, signs) = await _load(visitId);
      final parts = await seal(
        key: device.smsKey,
        deviceId: device.deviceId,
        plaintext: encodePlaintext(alertFields(visit, patient, signs)),
      );
      await sender.send(gatewayNumber, parts);
      await _repo.setState(visitId, DispatchState.sentSms);
    } on Exception {
      await _repo.setState(visitId, DispatchState.unconfirmed);
    }
  }

  /// Applies the 10-minute rule to every alert still waiting for its ack.
  Future<int> expire() => _repo.expireSentBefore(_now().subtract(ackTimeout));

  /// An "HB OK <code>" ack. Returns the visit it confirmed, or null if nothing was waiting.
  Future<String?> acknowledge(String shortCode) =>
      _repo.confirmShortCode(shortCode);

  /// Drains the acks the managed build's receiver collected (also while the app was closed).
  Future<void> applyAcks() async {
    for (final code in await sender.takeAcks()) {
      await acknowledge(code);
    }
  }

  /// The store build's "I got the confirmation".
  Future<void> confirm(String visitId) =>
      _repo.setState(visitId, DispatchState.confirmed);

  Future<void> _postAlert(String visitId) async {
    if (engine.session() == null) {
      throw const UrgentSendException('signed out');
    }
    final (visit, patient, signs) = await _load(visitId);
    final res = await engine.send(
      'POST',
      '/alerts',
      body: {
        'deviceId': await engine.deviceId(),
        'visit': visitPayload(visit, signs),
        'patient': patientPayload(patient),
      },
      timeout: internetTimeout,
    );
    if (res.statusCode != 200) {
      throw http.ClientException('alert refused (${res.statusCode})');
    }
  }

  Future<(Visit, Patient, List<String>)> _load(String visitId) async {
    final visit = (await VisitsRepository(db).get(visitId))!;
    final patient = (await PatientsRepository(db).get(visit.patientId))!;
    return (visit, patient, await VisitsRepository(db).signCodes(visitId));
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/auth/auth_service.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'firestore_mapping.dart';

/// Wait before the next try after the 1st, 2nd, 3rd and later failures (TRD §4).
Duration backoff(int attempts) => switch (attempts) {
  <= 1 => const Duration(seconds: 30),
  2 => const Duration(minutes: 2),
  3 => const Duration(minutes: 10),
  _ => const Duration(minutes: 30),
};

/// The name on a patient the server made from an SMS; the phone never pulls those.
const _stubPatientName = '(awaiting sync)';

class SyncReport {
  const SyncReport({
    this.online,
    this.pushed = 0,
    this.rejected = 0,
    this.error,
  });

  /// Null when sync did not try (nobody signed in).
  final bool? online;
  final int pushed;
  final int rejected;
  final String? error;
}

/// Uploads the outbox to Firestore in order, then pulls this CHW's patients, alert confirmations,
/// danger signs and the health centre's call number. The encrypted local database stays the copy the
/// app works from; Firestore's own offline cache is switched off (main.dart), so patient data on the
/// phone lives only in the encrypted database. Rows leave the outbox only once Firestore has accepted
/// them, and every write targets the record's own ID, so a retry after a dropped connection is harmless.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.auth,
    required this.session,
    required this.onSession,
    this._firestore,
    http.Client? client,
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final AuthService auth;
  final Session? Function() session;
  final void Function(Session) onSession;
  final FirebaseFirestore? _firestore;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  // Looked up on first use, so tests that never sync need no Firebase.
  FirebaseFirestore get fs => _firestore ?? FirebaseFirestore.instance;

  static const batchSize = 50;
  static const _deviceKey = 'device';
  static const _writeTimeout = Duration(seconds: 20);
  Future<SyncReport>? _running;

  /// Safe to call as often as you like: calls made while a run is going share that run.
  Future<SyncReport> run() =>
      _running ??= _run().whenComplete(() => _running = null);

  /// HEAD /health on the HealthBridge API with a 5 s timeout, tried twice so a serverless cold start
  /// does not read as offline. The API is also what registers the phone and merges SMS cases.
  Future<bool> reachable() async {
    for (var i = 0; i < 2; i++) {
      try {
        final res = await _client
            .head(Uri.parse('${auth.baseUrl}/health'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) return true;
      } on Exception {
        // try once more
      }
    }
    return false;
  }

  Future<SyncReport> _run() async {
    final s = session();
    if (s == null) return const SyncReport();
    if (!await reachable()) return const SyncReport(online: false);
    final hc = s.healthCenterId;
    if (hc == null) {
      return const SyncReport(online: true, error: 'no health centre');
    }

    var pushed = 0, rejected = 0;
    try {
      final deviceId = await this.deviceId();
      while (true) {
        final due = await _due();
        if (due.isEmpty) break;
        for (final row in due) {
          final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
          try {
            await _write(
              row,
              payload,
              s.userId,
              hc,
              deviceId,
            ).timeout(_writeTimeout);
          } on FirebaseException catch (e) {
            // The rules refused it: show it as failed and retry on the back-off schedule.
            if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
              await db.transaction(() async {
                await _backOff(row, e.code);
                await _setState(row, SyncState.failed);
              });
              rejected++;
              continue;
            }
            return await _stop(due, e, pushed, rejected);
          } on Exception catch (e) {
            // Network trouble or timeout: everything still queued waits for the next try.
            return await _stop(due, e, pushed, rejected);
          }
          await db.transaction(() async {
            await (db.delete(
              db.outbox,
            )..where((t) => t.id.equals(row.id))).go();
            final more =
                await (db.select(db.outbox)..where(
                      (t) =>
                          t.entity.equals(row.entity) &
                          t.entityId.equals(row.entityId),
                    ))
                    .get();
            if (more.isEmpty) await _setState(row, SyncState.synced);
          });
          pushed++;
        }
      }
      await _mergeSmsCases();
      await _pull(s.userId, hc);
      return SyncReport(online: true, pushed: pushed, rejected: rejected);
    } on Exception catch (e) {
      return SyncReport(
        online: true,
        pushed: pushed,
        rejected: rejected,
        error: '$e',
      );
    }
  }

  Future<SyncReport> _stop(
    List<OutboxData> due,
    Object e,
    int pushed,
    int rejected,
  ) async {
    final left = await (db.select(
      db.outbox,
    )..where((t) => t.id.isIn(due.map((r) => r.id)))).get();
    await db.transaction(() async {
      for (final r in left) {
        await _backOff(r, '$e');
      }
    });
    return SyncReport(
      online: true,
      pushed: pushed,
      rejected: rejected,
      error: '$e',
    );
  }

  Future<void> _write(
    OutboxData row,
    Map<String, dynamic> payload,
    String uid,
    String hc,
    String deviceId,
  ) => switch (row.entity) {
    'patient' =>
      fs
          .collection('patients')
          .doc(row.entityId)
          .set(firestorePatient(payload, chwId: uid, healthCenterId: hc)),
    _ =>
      fs
          .collection('visits')
          .doc(row.entityId)
          .set(
            firestoreVisit(
              payload,
              chwId: uid,
              healthCenterId: hc,
              deviceId: deviceId,
            ),
          ),
  };

  /// The internet channel of an urgent alert (TRD §5): the patient, the visit and its alert in one
  /// batch, so the supervisor never sees an alert without its visit. Throws when Firestore does not
  /// confirm within [timeout]; the caller then falls back to SMS.
  Future<void> raiseInternetAlert(
    Map<String, dynamic> visit,
    Map<String, dynamic>? patient, {
    required Duration timeout,
  }) async {
    final s = session();
    final hc = s?.healthCenterId;
    if (s == null || hc == null) throw StateError('signed out');
    final deviceId = await this.deviceId();
    final visitId = visit['id'] as String;
    final batch = fs.batch();
    if (patient != null) {
      batch.set(
        fs.collection('patients').doc(patient['id'] as String),
        firestorePatient(patient, chwId: s.userId, healthCenterId: hc),
      );
    }
    batch.set(
      fs.collection('visits').doc(visitId),
      firestoreVisit(
        visit,
        chwId: s.userId,
        healthCenterId: hc,
        deviceId: deviceId,
      ),
    );
    batch.set(
      fs.collection('alerts').doc(visitId),
      firestoreAlert(visitId, chwId: s.userId, healthCenterId: hc),
    );
    await batch.commit().timeout(timeout);
  }

  /// An urgent visit that also went by SMS reached the server first as a partial case. Once the full
  /// visit is uploaded the server folds the two into one (FR-14). Each visit is asked about once.
  Future<void> _mergeSmsCases() async {
    final smsSent = await (db.select(
      db.urgentDispatch,
    )..where((t) => t.channel.isNotValue('internet'))).get();
    for (final d in smsSent) {
      final visit = await (db.select(
        db.visits,
      )..where((t) => t.id.equals(d.visitId))).getSingleOrNull();
      if (visit?.syncState != SyncState.synced) continue;
      final key = 'merged:${d.visitId}';
      final done = await (db.select(
        db.syncMeta,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (done != null) continue;
      final res = await send('POST', '/visits/${d.visitId}/merge-sms');
      if (res.statusCode == 200) {
        await db
            .into(db.syncMeta)
            .insertOnConflictUpdate(
              SyncMetaCompanion.insert(
                key: key,
                value: _now().toIso8601String(),
              ),
            );
      }
    }
  }

  Future<List<OutboxData>> _due() {
    final now = _now();
    return (db.select(db.outbox)
          ..where(
            (t) =>
                t.nextTryAt.isNull() | t.nextTryAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(batchSize))
        .get();
  }

  Future<void> _backOff(OutboxData row, String error) {
    final attempts = row.attempts + 1;
    return (db.update(db.outbox)..where((t) => t.id.equals(row.id))).write(
      OutboxCompanion(
        attempts: Value(attempts),
        nextTryAt: Value(_now().add(backoff(attempts))),
        lastError: Value(error.length > 300 ? error.substring(0, 300) : error),
      ),
    );
  }

  Future<void> _setState(OutboxData row, SyncState state) =>
      switch (row.entity) {
        'patient' =>
          (db.update(db.patients)..where((t) => t.id.equals(row.entityId)))
              .write(PatientsCompanion(syncState: Value(state))),
        _ =>
          (db.update(db.visits)..where((t) => t.id.equals(row.entityId))).write(
            VisitsCompanion(syncState: Value(state)),
          ),
      };

  Future<void> _pull(String uid, String hc) async {
    final results = await Future.wait([
      fs.collection('patients').where('chwId', isEqualTo: uid).get(),
      fs.collection('alerts').where('chwId', isEqualTo: uid).get(),
      fs.collection('dangerSigns').get(),
    ]);
    final [patients, alerts, signs] = results;
    final centre = await fs.collection('healthCenters').doc(hc).get();

    await db.transaction(() async {
      for (final doc in patients.docs) {
        final p = doc.data();
        if (p['fullName'] == _stubPatientName) continue;
        final updated = fromTimestamp(p['updatedAt']);
        if (updated == null) continue;
        final local = await (db.select(
          db.patients,
        )..where((t) => t.id.equals(doc.id))).getSingleOrNull();
        // Never overwrite an edit that is still waiting to upload.
        if (local != null &&
            (local.syncState != SyncState.synced ||
                !updated.isAfter(local.updatedAt))) {
          continue;
        }
        await db
            .into(db.patients)
            .insertOnConflictUpdate(
              PatientsCompanion.insert(
                id: doc.id,
                shortId: p['shortId'] as String,
                fullName: p['fullName'] as String,
                village: p['village'] as String? ?? '',
                sex: Value(p['sex'] as String?),
                birthDate: Value(fromTimestamp(p['birthDate'])),
                ageEstimate: Value((p['ageEstimate'] as num?)?.toInt()),
                phone: Value(p['phone'] as String?),
                consentAt: fromTimestamp(p['consentAt']) ?? updated,
                createdAt: fromTimestamp(p['createdAt']) ?? updated,
                updatedAt: updated,
                archivedAt: Value(fromTimestamp(p['archivedAt'])),
                syncState: const Value(SyncState.synced),
              ),
            );
      }
      // The server only has an alert once the health centre has the case: that is the confirmation.
      for (final a in alerts.docs) {
        await (db.update(db.urgentDispatch)..where(
              (t) =>
                  t.visitId.equals(a.data()['visitId'] as String) &
                  t.state.equalsValue(DispatchState.confirmed).not(),
            ))
            .write(
              UrgentDispatchCompanion(
                state: const Value(DispatchState.confirmed),
                confirmedAt: Value(_now()),
              ),
            );
      }
      if (signs.docs.isNotEmpty) {
        await db.delete(db.dangerSigns).go();
        await db.batch(
          (b) => b.insertAll(db.dangerSigns, [
            for (final s in signs.docs)
              DangerSignsCompanion.insert(
                code: s.id,
                visitType: VisitType.values.byName(
                  s.data()['visitType'] as String,
                ),
                labelEn: s.data()['labelEn'] as String,
                labelRw: s.data()['labelRw'] as String? ?? '',
              ),
          ]),
        );
      }
      // The health centre's number for the urgent screen's call fallback, kept for offline use.
      if (centre.data()?['callNumber'] case final String call) {
        await db
            .into(db.syncMeta)
            .insertOnConflictUpdate(
              SyncMetaCompanion.insert(key: 'call_number', value: call),
            );
      }
      await db
          .into(db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(
              key: 'last_pull',
              value: _now().toIso8601String(),
            ),
          );
    });
  }

  /// The device ID and SMS key saved at registration for the signed-in CHW, without going online.
  /// Null until the first registration; the urgent SMS cannot be sealed before that.
  Future<({String deviceId, List<int> smsKey})?> savedDevice() async {
    final s = session();
    final saved = await _storage.read(key: _deviceKey);
    if (s == null || saved == null) return null;
    final j = jsonDecode(saved) as Map<String, dynamic>;
    if (j['userId'] != s.userId) return null;
    return (
      deviceId: j['deviceId'] as String,
      smsKey: base64.decode(j['smsKey'] as String),
    );
  }

  /// The server-issued device ID (and SMS key), registered once per signed-in CHW.
  Future<String> deviceId() async {
    final s = session()!;
    if (await savedDevice() case final saved?) return saved.deviceId;
    final res = await send(
      'POST',
      '/devices/register',
      body: {'buildFlavor': appFlavor == 'managed' ? 'managed' : 'store'},
    );
    if (res.statusCode != 201) {
      throw http.ClientException(
        'device registration failed (${res.statusCode})',
      );
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    await _storage.write(
      key: _deviceKey,
      value: jsonEncode({
        'userId': s.userId,
        'deviceId': j['deviceId'],
        'smsKey': j['smsKey'],
      }),
    );
    return j['deviceId'] as String;
  }

  /// A call to the HealthBridge API with the Firebase ID token; an expired token is refreshed once
  /// and the request repeated.
  Future<http.Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    Future<http.Response> go(Session s) {
      final uri = Uri.parse('${auth.baseUrl}$path')
          .replace(queryParameters: query);
      final headers = {
        'authorization': 'Bearer ${s.accessToken}',
        'content-type': 'application/json',
      };
      final req = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      return req.timeout(timeout);
    }

    var s = session()!;
    var res = await go(s);
    if (res.statusCode == 401) {
      s = await auth.refresh(s);
      onSession(s);
      res = await go(s);
    }
    return res;
  }
}

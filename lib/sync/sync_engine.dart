import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/auth/auth_service.dart';
import '../data/db.dart';
import '../data/models.dart';

/// Wait before the next try after the 1st, 2nd, 3rd and later failures (TRD §4).
Duration backoff(int attempts) => switch (attempts) {
  <= 1 => const Duration(seconds: 30),
  2 => const Duration(minutes: 2),
  3 => const Duration(minutes: 10),
  _ => const Duration(minutes: 30),
};

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

/// Drains the outbox to POST /sync/push in order, 50 at a time, then applies GET /sync/pull.
/// Rows only leave the outbox once the server has accepted them, so a crash or a dropped
/// connection at any point loses nothing; the server is idempotent by UUID, so resending is safe.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.auth,
    required this.session,
    required this.onSession,
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
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  static const batchSize = 50;
  static const _deviceKey = 'device';
  Future<SyncReport>? _running;

  /// Safe to call as often as you like: calls made while a run is going share that run.
  Future<SyncReport> run() =>
      _running ??= _run().whenComplete(() => _running = null);

  /// HEAD /health with a 5 s timeout, tried twice so a serverless cold start does not read as offline.
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
    if (session() == null) return const SyncReport();
    if (!await reachable()) return const SyncReport(online: false);

    var pushed = 0, rejected = 0;
    try {
      final deviceId = await this.deviceId();
      while (true) {
        final due = await _due();
        if (due.isEmpty) break;
        final http.Response res;
        try {
          res = await send(
            'POST',
            '/sync/push',
            body: {
              'deviceId': deviceId,
              'changes': [
                for (final r in due)
                  {
                    'seq': r.id,
                    'entity': r.entity,
                    'op': r.op.name,
                    'payload': jsonDecode(r.payloadJson),
                  },
              ],
            },
          );
          if (res.statusCode != 200) {
            throw http.ClientException('push failed (${res.statusCode})');
          }
        } on Exception catch (e) {
          await db.transaction(() async {
            for (final r in due) {
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
        final results = {
          for (final r in (jsonDecode(res.body) as Map)['results'] as List)
            (r as Map)['seq'] as int: r,
        };
        await db.transaction(() async {
          for (final row in due) {
            final r = results[row.id];
            if (r?['ok'] == true) {
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
              pushed++;
            } else {
              // Refused (or not answered): show it as failed and retry on the back-off schedule.
              await _backOff(row, r?['error'] as String? ?? 'no result');
              await _setState(row, SyncState.failed);
              rejected++;
            }
          }
        });
      }
      await _pull(deviceId);
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

  Future<void> _pull(String deviceId) async {
    final since = await (db.select(
      db.syncMeta,
    )..where((t) => t.key.equals('last_pull'))).getSingleOrNull();
    final res = await send(
      'GET',
      '/sync/pull',
      query: {'deviceId': deviceId, 'since': ?since?.value},
    );
    if (res.statusCode != 200) {
      throw http.ClientException('pull failed (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    DateTime? date(Object? v) => v == null ? null : DateTime.parse(v as String);

    await db.transaction(() async {
      for (final p in (j['patients'] as List).cast<Map<String, dynamic>>()) {
        final local = await (db.select(
          db.patients,
        )..where((t) => t.id.equals(p['id'] as String))).getSingleOrNull();
        final updated = date(p['updated_at'])!;
        // Never overwrite an edit that is still waiting to upload; it wins on the server by updated_at.
        if (local != null &&
            (local.syncState != SyncState.synced ||
                !updated.isAfter(local.updatedAt))) {
          continue;
        }
        await db
            .into(db.patients)
            .insertOnConflictUpdate(
              PatientsCompanion.insert(
                id: p['id'] as String,
                shortId: p['short_id'] as String,
                fullName: p['full_name'] as String,
                village: p['village'] as String,
                sex: Value(p['sex'] as String?),
                birthDate: Value(date(p['birth_date'])),
                ageEstimate: Value(p['age_estimate'] as int?),
                phone: Value(p['phone'] as String?),
                consentAt: date(p['consent_at'])!,
                createdAt: date(p['created_at'])!,
                updatedAt: updated,
                syncState: const Value(SyncState.synced),
              ),
            );
      }
      // The server only has an alert once the health centre has the case: that is the confirmation.
      for (final a in (j['alerts'] as List).cast<Map<String, dynamic>>()) {
        await (db.update(db.urgentDispatch)..where(
              (t) =>
                  t.visitId.equals(a['visit_id'] as String) &
                  t.state.equalsValue(DispatchState.confirmed).not(),
            ))
            .write(
              UrgentDispatchCompanion(
                state: const Value(DispatchState.confirmed),
                confirmedAt: Value(_now()),
              ),
            );
      }
      final signs = (j['dangerSigns'] as List).cast<Map<String, dynamic>>();
      if (signs.isNotEmpty) {
        await db.delete(db.dangerSigns).go();
        await db.batch(
          (b) => b.insertAll(db.dangerSigns, [
            for (final s in signs)
              DangerSignsCompanion.insert(
                code: s['code'] as String,
                visitType: VisitType.values.byName(s['visit_type'] as String),
                labelEn: s['label_en'] as String,
                labelRw: s['label_rw'] as String,
              ),
          ]),
        );
      }
      // The health centre's number for the urgent screen's call fallback, kept for offline use.
      if (j['callNumber'] case final String call) {
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
              value: j['serverTime'] as String,
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

  /// Authenticated request; an expired access token is refreshed once and the request repeated.
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
          : _client.post(uri, headers: headers, body: jsonEncode(body));
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

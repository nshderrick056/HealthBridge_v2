import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:workmanager/workmanager.dart';

import '../core/auth/auth_service.dart';
import '../data/db.dart';
import 'sync_engine.dart';

const _task = 'rw.healthbridge.sync';

/// WorkManager is Android's; the web and Windows builds only sync while open.
bool get _supported => !kIsWeb && Platform.isAndroid;

/// Drains the outbox every 30 minutes while signed in, even with the app closed, as soon as there is
/// a network (TRD §2/§4). Calling it again keeps the existing schedule.
Future<void> scheduleBackgroundSync() async {
  if (!_supported) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _task,
    _task,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<void> cancelBackgroundSync() async {
  if (_supported) await Workmanager().cancelByUniqueName(_task);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((_, _) => backgroundSync());
}

/// One sync in the WorkManager isolate, with the saved session and the encrypted database. Always
/// reports success: outbox rows keep their own back-off and the next run is 30 minutes away.
Future<bool> backgroundSync({
  AuthService? auth,
  Future<AppDatabase> Function() openDb = openAppDatabase,
}) async {
  auth ??= AuthService();
  var session = await auth.restore();
  if (session == null) return true;
  final db = await openDb();
  try {
    // AuthService.refresh saves the new token, so the app and the next run start from it.
    await SyncEngine(
      db: db,
      auth: auth,
      session: () => session,
      onSession: (s) => session = s,
    ).run();
  } finally {
    await db.close();
  }
  return true;
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'forms/danger_signs.dart';
import 'models.dart';

part 'db.g.dart';

// Backend Schema section 2. Times are UTC; ids are UUID v4 generated on the phone.

class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get shortId => text().unique()(); // e.g. P3FA9C1, safe for SMS
  TextColumn get fullName => text()();
  TextColumn get sex => text().nullable()(); // F | M
  DateTimeColumn get birthDate => dateTime().nullable()();
  IntColumn get ageEstimate => integer().nullable()();
  TextColumn get village => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get consentAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => textEnum<SyncState>().withDefault(Constant(SyncState.local.name))();

  @override
  Set<Column> get primaryKey => {id};
}

class Visits extends Table {
  TextColumn get id => text()();
  TextColumn get shortCode => text()(); // first 8 hex of id, used in SMS
  TextColumn get patientId => text().references(Patients, #id)();
  TextColumn get type => textEnum<VisitType>()();
  TextColumn get answersJson => text().withDefault(const Constant('{}'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isUrgent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get followUpOn => dateTime().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get syncState => textEnum<SyncState>().withDefault(Constant(SyncState.local.name))();

  @override
  Set<Column> get primaryKey => {id};
}

class VisitDangerSigns extends Table {
  TextColumn get visitId => text().references(Visits, #id)();
  TextColumn get code => text()();

  @override
  Set<Column> get primaryKey => {visitId, code};
}

/// Ordered upload queue: one row per local change, drained oldest first by the sync engine.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()(); // patient | visit
  TextColumn get entityId => text()();
  TextColumn get op => textEnum<OutboxOp>()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextTryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}

class UrgentDispatch extends Table {
  TextColumn get visitId => text().references(Visits, #id)();
  TextColumn get channel => text()(); // internet | sms_composer | sms_direct
  TextColumn get state => textEnum<DispatchState>()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {visitId};
}

/// Autosave for half-filled forms, one row per screen.
class Drafts extends Table {
  TextColumn get id => text()();
  TextColumn get screen => text()();
  TextColumn get dataJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class DangerSigns extends Table {
  TextColumn get code => text()();
  TextColumn get visitType => textEnum<VisitType>()();
  TextColumn get labelEn => text()();
  TextColumn get labelRw => text()();

  @override
  Set<Column> get primaryKey => {code};
}

@DriftDatabase(tables: [
  Patients,
  Visits,
  VisitDangerSigns,
  Outbox,
  UrgentDispatch,
  Drafts,
  SyncMeta,
  DangerSigns,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await batch((b) => b.insertAll(dangerSigns, [
                for (final s in seedDangerSigns)
                  DangerSignsCompanion.insert(
                      code: s.code, visitType: s.type, labelEn: s.labelEn, labelRw: s.labelRw),
              ]));
        },
        beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
      );
}

const _keyName = 'db_key';

/// The SQLCipher key is random, made on first launch and kept in the Android Keystore.
Future<String> _databaseKey() async {
  const storage = FlutterSecureStorage();
  var key = await storage.read(key: _keyName);
  if (key == null) {
    final bytes = [...const Uuid().v4obj().toBytes(), ...const Uuid().v4obj().toBytes()];
    key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _keyName, value: key);
  }
  return key;
}

/// Opens the encrypted on-device database (SQLCipher build of sqlite3, see the pubspec hooks).
Future<AppDatabase> openAppDatabase() async {
  final key = await _databaseKey();
  final dir = await getApplicationSupportDirectory();
  return AppDatabase(NativeDatabase.createInBackground(
    File(p.join(dir.path, 'healthbridge.db')),
    setup: (raw) => raw.execute("PRAGMA key = \"x'$key'\";"),
  ));
}

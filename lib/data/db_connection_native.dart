import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart';

const _keyName = 'db_key';

Future<String> _databaseKey() async {
  const storage = FlutterSecureStorage();
  var key = await storage.read(key: _keyName);
  if (key == null) {
    final bytes = [
      ...const Uuid().v4obj().toBytes(),
      ...const Uuid().v4obj().toBytes(),
    ];
    key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _keyName, value: key);
  }
  return key;
}

Future<QueryExecutor> openDatabaseExecutor() async {
  final key = await _databaseKey();
  final dir = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'healthbridge.db')),
    setup: (raw) => raw.execute("PRAGMA key = \"x'$key'\";"),
  );
}

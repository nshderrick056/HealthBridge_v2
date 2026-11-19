import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

Future<QueryExecutor> openDatabaseExecutor() async {
  final result = await WasmDatabase.open(
    databaseName: 'healthbridge',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return result.resolvedExecutor;
}

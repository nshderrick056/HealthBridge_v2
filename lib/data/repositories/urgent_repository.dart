import 'package:drift/drift.dart';

import '../db.dart';
import '../models.dart';

/// Tracks an urgent alert's progress (sending -> sent_sms -> confirmed | unconfirmed).
/// The senders that move it past `sending` are slice 6.
class UrgentRepository {
  UrgentRepository(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<void> start(String visitId, {String channel = 'internet'}) => _db
      .into(_db.urgentDispatch)
      .insertOnConflictUpdate(
        UrgentDispatchCompanion.insert(
          visitId: visitId,
          channel: channel,
          state: DispatchState.sending,
          sentAt: Value(_now()),
        ),
      );

  Stream<UrgentDispatchData?> watch(String visitId) => (_db.select(
    _db.urgentDispatch,
  )..where((t) => t.visitId.equals(visitId))).watchSingleOrNull();

  Future<void> setState(String visitId, DispatchState state) =>
      (_db.update(
        _db.urgentDispatch,
      )..where((t) => t.visitId.equals(visitId))).write(
        UrgentDispatchCompanion(
          state: Value(state),
          confirmedAt: state == DispatchState.confirmed
              ? Value(_now())
              : const Value.absent(),
        ),
      );
}

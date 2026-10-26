import 'package:drift/drift.dart';

import '../db.dart';
import '../models.dart';

/// Tracks an urgent alert's progress (sending -> sent_sms -> confirmed | unconfirmed).
/// `lib/urgent/urgent_dispatcher.dart` drives the transitions.
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
          confirmedAt: const Value(null),
        ),
      );

  Future<UrgentDispatchData?> get(String visitId) => (_db.select(
    _db.urgentDispatch,
  )..where((t) => t.visitId.equals(visitId))).getSingleOrNull();

  Stream<UrgentDispatchData?> watch(String visitId) => (_db.select(
    _db.urgentDispatch,
  )..where((t) => t.visitId.equals(visitId))).watchSingleOrNull();

  /// `sentAt` is stamped when the SMS leaves the phone, which starts the 10-minute wait for the ack.
  Future<void> setState(
    String visitId,
    DispatchState state, {
    String? channel,
  }) =>
      (_db.update(
        _db.urgentDispatch,
      )..where((t) => t.visitId.equals(visitId))).write(
        UrgentDispatchCompanion(
          state: Value(state),
          channel: channel == null ? const Value.absent() : Value(channel),
          sentAt: state == DispatchState.sentSms
              ? Value(_now())
              : const Value.absent(),
          confirmedAt: state == DispatchState.confirmed
              ? Value(_now())
              : const Value.absent(),
        ),
      );

  /// SMS sent before [cutoff] and still not acknowledged become unconfirmed. Returns how many.
  Future<int> expireSentBefore(DateTime cutoff) =>
      (_db.update(_db.urgentDispatch)..where(
            (t) =>
                t.state.equalsValue(DispatchState.sentSms) &
                t.sentAt.isSmallerOrEqualValue(cutoff),
          ))
          .write(
            const UrgentDispatchCompanion(
              state: Value(DispatchState.unconfirmed),
            ),
          );

  /// Applies an `HB OK <shortCode>` ack. Returns the visit it confirmed, or null if none was waiting.
  Future<String?> confirmShortCode(String shortCode) =>
      _db.transaction(() async {
        final visits = await (_db.select(
          _db.visits,
        )..where((t) => t.shortCode.equals(shortCode))).get();
        for (final v in visits) {
          final d = await get(v.id);
          if (d != null && d.state != DispatchState.confirmed) {
            await setState(v.id, DispatchState.confirmed);
            return v.id;
          }
        }
        return null;
      });
}

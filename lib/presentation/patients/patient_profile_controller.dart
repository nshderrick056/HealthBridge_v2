import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/providers.dart';
import '../../sync/sync_service.dart';

/// Archive (the app's "delete") and its undo. Both sync like any other edit.
class PatientActions {
  PatientActions(this._ref);

  final Ref _ref;

  Future<Patient> archive(Patient p) async {
    final archived = await _ref.read(archivePatientProvider).call(p);
    unawaited(_ref.read(syncNowProvider)());
    return archived;
  }

  Future<void> restore(Patient p) async {
    await _ref.read(archivePatientProvider).undo(p);
    unawaited(_ref.read(syncNowProvider)());
  }
}

final patientActionsProvider = Provider(PatientActions.new);

/// Whether a patient's profile shows the full visit history, per patient ID.
class HistoryExpandedController extends Notifier<bool> {
  HistoryExpandedController(this.patientId);

  final String patientId;

  @override
  bool build() => false;

  void toggle() => state = !state;
}

final historyExpandedProvider = NotifierProvider.autoDispose
    .family<HistoryExpandedController, bool, String>(
      HistoryExpandedController.new,
    );

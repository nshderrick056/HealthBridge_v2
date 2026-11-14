import 'package:flutter_riverpod/flutter_riverpod.dart';

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

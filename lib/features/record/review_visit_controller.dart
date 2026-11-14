import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/providers.dart';
import '../../sync/sync_service.dart';
import 'visit_form.dart';

/// Submits a reviewed visit. The state is "saving", which disables the Submit button.
class SubmitVisitController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Saves the visit (with its outbox row), drops the draft and starts an upload if online.
  Future<Visit> submit(VisitForm f, String draftKey) async {
    state = true;
    try {
      final visit = await ref
          .read(visitsRepositoryProvider)
          .record(
            patientId: f.patient.id,
            type: f.type,
            answers: f.answers,
            signCodes: f.signs.toList(),
            notes: f.notes.trim().isEmpty ? null : f.notes.trim(),
          );
      await ref.read(draftsRepositoryProvider).delete(draftKey);
      // Upload now if online; the outbox keeps it otherwise.
      unawaited(ref.read(syncNowProvider)());
      return visit;
    } catch (_) {
      if (ref.mounted) state = false;
      rethrow;
    }
  }
}

final submitVisitProvider =
    NotifierProvider.autoDispose<SubmitVisitController, bool>(
      SubmitVisitController.new,
    );

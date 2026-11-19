import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/supervision.dart';

/// The inbox filter: `open` (everything not resolved), a status's wire name, or null for all.
class InboxFilterController extends Notifier<String?> {
  @override
  String? build() => 'open';

  void show(String? filter) => state = filter;
}

final inboxFilterProvider = NotifierProvider<InboxFilterController, String?>(
  InboxFilterController.new,
);

/// The health centre's alerts, refreshed every 10 s while the inbox is on screen (like the dashboard).
final inboxProvider = StreamProvider.autoDispose<List<AlertSummary>>((
  ref,
) async* {
  final repo = ref.watch(supervisionRepositoryProvider);
  final filter = ref.watch(inboxFilterProvider);
  while (true) {
    yield await repo.alerts(status: filter);
    await Future<void>.delayed(const Duration(seconds: 10));
  }
});

final caseProvider = FutureProvider.autoDispose.family<AlertDetail, String>(
  (ref, id) => ref.watch(supervisionRepositoryProvider).alert(id),
);

final chwsProvider = FutureProvider.autoDispose<List<ChwSummary>>(
  (ref) => ref.watch(supervisionRepositoryProvider).chws(),
);

/// Moving a case to a new status. The state is "saving", which disables the buttons.
class CaseStatusController extends Notifier<bool> {
  CaseStatusController(this.alertId);

  final String alertId;

  @override
  bool build() => false;

  /// Returns null on success, or a message to show.
  Future<String?> move(AlertStatus to, String note) async {
    state = true;
    try {
      await ref
          .read(supervisionRepositoryProvider)
          .setStatus(alertId, to, note: note);
      ref.invalidate(caseProvider(alertId));
      ref.invalidate(inboxProvider);
      return null;
    } on Exception catch (e) {
      return e.toString().contains('invalid_transition')
          ? 'Someone else changed this case. It has been refreshed.'
          : 'Could not save. Check your connection and try again.';
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final caseStatusProvider = NotifierProvider.autoDispose
    .family<CaseStatusController, bool, String>(CaseStatusController.new);

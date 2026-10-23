import 'dart:async';

import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../sync/sync_service.dart';
import 'urgent_dispatcher.dart';
import 'urgent_sender.dart';

final urgentSenderProvider = Provider<UrgentSender>(
  (ref) => senderForFlavor(appFlavor),
);

final urgentDispatcherProvider = Provider(
  (ref) => UrgentDispatcher(
    db: ref.watch(databaseProvider),
    engine: ref.watch(syncEngineProvider),
    sender: ref.watch(urgentSenderProvider),
  ),
);

/// The health centre's number for the Call button, saved by the last sync. Null before the first one.
final callNumberProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.syncMeta)..where((t) => t.key.equals('call_number')))
      .watchSingleOrNull()
      .map((r) => r?.value);
});

/// Keeps urgent alerts moving while the CHW is signed in: applies "HB OK" acks as they arrive and
/// on resume, and the 10-minute "unconfirmed" rule every 15 s (the timer runs on the phone).
class UrgentWatcher extends ConsumerStatefulWidget {
  const UrgentWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UrgentWatcher> createState() => _UrgentWatcherState();
}

class _UrgentWatcherState extends ConsumerState<UrgentWatcher> {
  late final AppLifecycleListener _lifecycle;
  late final Timer _tick;

  void _check() => unawaited(_run());

  Future<void> _run() async {
    final dispatcher = ref.read(urgentDispatcherProvider);
    try {
      await dispatcher.applyAcks();
    } on Exception {
      // The channel is unavailable (e.g. on a desktop preview); the 10-minute rule still applies.
    }
    await dispatcher.expire();
  }

  @override
  void initState() {
    super.initState();
    final sender = ref.read(urgentSenderProvider);
    sender.onAck(_check);
    unawaited(sender.prepare().then((_) {}, onError: (Object _) {}));
    _lifecycle = AppLifecycleListener(onResume: _check);
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

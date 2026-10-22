import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'sync_engine.dart';

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    db: ref.watch(databaseProvider),
    auth: ref.watch(authServiceProvider),
    session: () => ref.read(sessionProvider),
    onSession: (s) => ref.read(sessionProvider.notifier).state = s,
  ),
);

/// Starts a sync and records whether the server answered. Screens call it fire-and-forget after a save.
final syncNowProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final report = await ref.read(syncEngineProvider).run();
    if (report.online case final online?) {
      ref.read(isOnlineProvider.notifier).state = online;
    }
  },
);

/// Runs sync while the CHW is signed in: on start, on resume, when connectivity changes, and every
/// minute (the outbox back-off decides what is actually due).
// shortcut: only while the app is open; a workmanager job is needed to sync with the app closed.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  late final Timer _tick;

  void _sync() => unawaited(ref.read(syncNowProvider)());

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    _connectivity = Connectivity().onConnectivityChanged.listen(
      (_) => _sync(),
      onError: (_) {},
    );
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _connectivity?.cancel();
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

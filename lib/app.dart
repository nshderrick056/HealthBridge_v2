import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/settings.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/shell/role_shells.dart';
import 'sync/sync_service.dart';
import 'urgent/urgent_service.dart';

class HealthBridgeApp extends ConsumerStatefulWidget {
  const HealthBridgeApp({super.key});

  @override
  ConsumerState<HealthBridgeApp> createState() => _HealthBridgeAppState();
}

class _HealthBridgeAppState extends ConsumerState<HealthBridgeApp> {
  late final Future<void> _restore = ref
      .read(authServiceProvider)
      .restore()
      .then((s) {
        ref.read(sessionProvider.notifier).state = s;
      });

  @override
  Widget build(BuildContext context) {
    final textScale = ref.watch(settingsProvider).textSize.scale;
    return MaterialApp(
      title: 'HealthBridge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // The chosen text size multiplies the phone's own font size setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
          ),
          child: child!,
        );
      },
      home: FutureBuilder<void>(
        future: _restore,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: SizedBox.shrink());
          }
          // Each role gets its own screens; only CHWs record visits, sync and send urgent alerts.
          return switch (ref.watch(sessionProvider)?.role) {
            null => const LoginScreen(),
            'supervisor' => const SupervisorShell(),
            'admin' => const AdminShell(),
            _ => const SyncTriggers(child: UrgentWatcher(child: AppShell())),
          };
        },
      ),
    );
  }
}

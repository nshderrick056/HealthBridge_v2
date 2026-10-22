import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';

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
    final signedIn = ref.watch(sessionProvider) != null;
    return MaterialApp(
      title: 'HealthBridge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: FutureBuilder<void>(
        future: _restore,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: SizedBox.shrink());
          }
          return signedIn ? const AppShell() : const LoginScreen();
        },
      ),
    );
  }
}

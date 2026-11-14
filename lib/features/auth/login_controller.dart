import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/settings/settings.dart';
import '../../data/providers.dart';

class LoginState {
  const LoginState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Signs the CHW in. Success sets [sessionProvider], which swaps the login screen for the app.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> submit(String id, String secret) async {
    state = const LoginState(busy: true);
    try {
      final session = await ref.read(authServiceProvider).login(id, secret);
      await ref.read(settingsProvider.notifier).loggedInAs(id);
      ref.read(sessionProvider.notifier).state = session;
    } on AuthException catch (e) {
      if (ref.mounted) state = LoginState(error: e.message);
      return;
    }
    if (ref.mounted) state = const LoginState();
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

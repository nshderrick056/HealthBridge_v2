import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../data/providers.dart';

class ChangeSecretState {
  const ChangeSecretState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

/// First sign-in with the temporary PIN/password from the admin's SMS: the user sets their own.
class ChangeSecretController extends Notifier<ChangeSecretState> {
  @override
  ChangeSecretState build() => const ChangeSecretState();

  Future<void> save({String? pin, String? password}) async {
    state = const ChangeSecretState(busy: true);
    try {
      final session = await ref
          .read(authServiceProvider)
          .changeOwn(pin: pin, password: password);
      ref.read(sessionProvider.notifier).state = session;
    } on AuthException catch (e) {
      if (ref.mounted) state = ChangeSecretState(error: e.message);
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    ref.read(sessionProvider.notifier).state = null;
  }
}

final changeSecretProvider =
    NotifierProvider.autoDispose<ChangeSecretController, ChangeSecretState>(
      ChangeSecretController.new,
    );

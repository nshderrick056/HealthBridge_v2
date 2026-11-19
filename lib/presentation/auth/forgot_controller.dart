import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../data/providers.dart';

/// Forgot PIN or password: ask -> an admin approves and a code is texted -> enter it -> set a new one.
enum ForgotStep { who, code, newSecret, done }

class ForgotState {
  const ForgotState({
    this.step = ForgotStep.who,
    this.busy = false,
    this.error,
    this.byEmail = false,
    this.id = '',
    this.resetToken,
  });

  final ForgotStep step;
  final bool busy;
  final String? error;

  /// Asked by email instead of phone (only accounts with a password have one).
  final bool byEmail;
  final String id;
  final String? resetToken;

  ForgotState copyWith({
    ForgotStep? step,
    bool? busy,
    String? Function()? error,
    String? id,
    String? resetToken,
  }) => ForgotState(
    step: step ?? this.step,
    busy: busy ?? this.busy,
    error: error != null ? error() : this.error,
    byEmail: byEmail,
    id: id ?? this.id,
    resetToken: resetToken ?? this.resetToken,
  );
}

class ForgotController extends Notifier<ForgotState> {
  @override
  ForgotState build() => const ForgotState();

  AuthService get _auth => ref.read(authServiceProvider);

  void useEmail(bool byEmail) => state = ForgotState(byEmail: byEmail);

  /// Step 1: flags the request for the admin.
  Future<void> request(String id) => _step(() async {
    await _auth.requestReset(
      phone: state.byEmail ? null : id,
      email: state.byEmail ? id : null,
    );
    return state.copyWith(step: ForgotStep.code, id: id);
  });

  /// Step 2: the code the admin's approval texted.
  Future<void> verify(String code) => _step(() async {
    final token = await _auth.verifyResetCode(
      phone: state.byEmail ? null : state.id,
      email: state.byEmail ? state.id : null,
      code: code,
    );
    return state.copyWith(step: ForgotStep.newSecret, resetToken: token);
  });

  /// Step 3: the new PIN (phone) or password (email).
  Future<void> complete({String? pin, String? password}) => _step(() async {
    await _auth.completeReset(state.resetToken!, pin: pin, password: password);
    return state.copyWith(step: ForgotStep.done);
  });

  Future<void> _step(Future<ForgotState> Function() run) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      final next = await run();
      if (ref.mounted) state = next.copyWith(busy: false);
    } on AuthException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: () => e.message);
      }
    }
  }
}

final forgotControllerProvider =
    NotifierProvider.autoDispose<ForgotController, ForgotState>(
      ForgotController.new,
    );

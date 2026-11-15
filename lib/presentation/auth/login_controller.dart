import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/settings/settings.dart';
import '../../data/providers.dart';

/// The three ways to sign in. Accounts are made by an admin; none of these creates one.
enum LoginMethod { pin, smsCode, email }

class LoginState {
  const LoginState({
    this.method = LoginMethod.pin,
    this.busy = false,
    this.error,
    this.verificationId,
  });

  final LoginMethod method;
  final bool busy;
  final String? error;

  /// Set once Firebase has texted a code: the form then asks for it.
  final String? verificationId;

  bool get awaitingCode => verificationId != null;

  LoginState copyWith({
    bool? busy,
    String? Function()? error,
    String? Function()? verificationId,
  }) => LoginState(
    method: method,
    busy: busy ?? this.busy,
    error: error != null ? error() : this.error,
    verificationId: verificationId != null
        ? verificationId()
        : this.verificationId,
  );
}

/// Signs the user in. Success sets [sessionProvider], which swaps the login screen for the app.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthService get _auth => ref.read(authServiceProvider);

  void choose(LoginMethod method) => state = LoginState(method: method);

  /// Phone + PIN, or email + password.
  Future<void> submit(String id, String secret) => _run(
    id,
    () => state.method == LoginMethod.email
        ? _auth.signInWithEmail(id.trim(), secret)
        : _auth.signInWithPin(normalizePhone(id), secret),
  );

  /// First step of SMS-code sign-in: Firebase texts the code.
  Future<void> sendCode(String phone) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      final sent = await _auth.sendPhoneCode(normalizePhone(phone));
      if (!ref.mounted) return;
      if (sent.signedIn) {
        // Android read the SMS itself and has already signed in.
        await _done(phone, await _auth.restore());
      } else {
        state = state.copyWith(
          busy: false,
          verificationId: () => sent.verificationId,
        );
      }
    } on AuthException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: () => e.message);
      }
    }
  }

  /// Second step: the 6-digit code from the SMS.
  Future<void> confirmCode(String phone, String code) => _run(
    phone,
    () => _auth.confirmPhoneCode(state.verificationId!, code.trim()),
  );

  /// Back from the code step, to change the number or send again.
  void changeNumber() => state = const LoginState(method: LoginMethod.smsCode);

  Future<void> _run(String id, Future<Session> Function() signIn) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _done(id, await signIn());
    } on AuthException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: () => e.message);
      }
    }
  }

  Future<void> _done(String id, Session? session) async {
    if (session == null) return;
    await ref.read(settingsProvider.notifier).loggedInAs(id);
    ref.read(sessionProvider.notifier).state = session;
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

String? requiredField(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

String? validatePin(String? v) =>
    requiredField(v) ??
    (RegExp(r'^\d{4,6}$').hasMatch(v!.trim()) ? null : 'PIN is 4 to 6 digits');

String? validatePhone(String? v) =>
    requiredField(v) ??
    (RegExp(r'^\+?\d{9,15}$').hasMatch(v!.replaceAll(RegExp(r'[\s\-()]'), ''))
        ? null
        : 'Enter a phone number, e.g. 0788 123 456');

String? validateEmail(String? v) =>
    requiredField(v) ??
    (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
        ? null
        : 'Enter a valid email address');

String? validatePassword(String? v) =>
    requiredField(v) ??
    (v!.length >= 8 ? null : 'Password is at least 8 characters');

String? validateCode(String? v) =>
    requiredField(v) ??
    (RegExp(r'^\d{6}$').hasMatch(v!.trim()) ? null : 'The code has 6 digits');

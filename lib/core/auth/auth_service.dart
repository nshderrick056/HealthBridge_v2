import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

const _apiUrlOverride = String.fromEnvironment('API_URL');

/// `--dart-define=API_URL=...` wins. Otherwise the dev server on this PC: the Android emulator
/// reaches it at 10.0.2.2, a browser at localhost.
final apiUrl = _apiUrlOverride.isNotEmpty
    ? _apiUrlOverride
    : (kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000');

/// Who is signed in. Built from the Firebase user and the role claims the server set on the account.
class Session {
  const Session({
    required this.accessToken,
    required this.userId,
    required this.fullName,
    this.role = 'chw',
    this.healthCenterId,
  });

  /// The Firebase ID token, sent to the HealthBridge API as `Authorization: Bearer ...`.
  final String accessToken;
  final String userId;
  final String fullName;

  /// chw | supervisor | admin
  final String role;
  final String? healthCenterId;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The result of asking Firebase to text a sign-in code.
class PhoneCode {
  const PhoneCode(this.verificationId) : signedIn = false;

  /// Android read the code itself and has already signed in.
  const PhoneCode.signedIn() : verificationId = null, signedIn = true;

  final String? verificationId;
  final bool signedIn;
}

/// Sign-in and the forgot-PIN/password flow. Accounts are made by an admin only (sign-up is off in
/// Firebase), so every method here signs in to an existing account.
///   - phone + PIN: the HealthBridge API checks the PIN and returns a Firebase custom token
///   - phone + SMS code, email + password: straight to Firebase Auth
/// Firebase keeps the user signed in across restarts (and offline), so there is no token storage here.
class AuthService {
  AuthService({FirebaseAuth? auth, http.Client? client, String? baseUrl})
    : _authOverride = auth,
      _client = client ?? http.Client(),
      baseUrl = baseUrl ?? apiUrl;

  final FirebaseAuth? _authOverride;
  final http.Client _client;
  final String baseUrl;

  // Looked up on first use, so code that never signs in (most widget tests) needs no Firebase.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// The login form's single entry: an email signs in with its password, anything else is a phone + PIN.
  Future<Session> login(String id, String secret) => id.contains('@')
      ? signInWithEmail(id.trim(), secret)
      : signInWithPin(normalizePhone(id), secret);

  Future<Session> signInWithPin(String phone, String pin) async {
    final res = await _post('/auth/pin', {'phone': phone, 'pin': pin});
    if (res.statusCode == 429) {
      throw AuthException('Too many attempts. Try again in 15 minutes.');
    }
    if (res.statusCode != 200) {
      throw AuthException('Wrong phone number or PIN.');
    }
    final token = (jsonDecode(res.body) as Map)['customToken'] as String;
    return _signedIn(() => _auth.signInWithCustomToken(token));
  }

  Future<Session> signInWithEmail(String email, String password) => _signedIn(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  /// Asks Firebase to text a 6-digit code to [phone] (international format).
  Future<PhoneCode> sendPhoneCode(String phone) {
    final done = Completer<PhoneCode>();
    _auth
        .verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            if (done.isCompleted) return;
            try {
              await _auth.signInWithCredential(credential);
              done.complete(const PhoneCode.signedIn());
            } on Object catch (e) {
              done.completeError(_friendly(e));
            }
          },
          verificationFailed: (e) {
            if (!done.isCompleted) done.completeError(_friendly(e));
          },
          codeSent: (id, _) {
            if (!done.isCompleted) done.complete(PhoneCode(id));
          },
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError((Object e) {
          if (!done.isCompleted) done.completeError(_friendly(e));
        });
    return done.future;
  }

  Future<Session> confirmPhoneCode(String verificationId, String code) =>
      _signedIn(
        () => _auth.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          ),
        ),
      );

  /// The session for whoever Firebase says is signed in now; null when nobody is.
  Future<Session?> restore() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _session(user);
    } on Object {
      return null;
    }
  }

  /// A fresh ID token (they last an hour). Throws [AuthException] if the account was disabled or a
  /// PIN/password reset signed this phone out.
  Future<Session> refresh(Session s) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != s.userId) {
      throw AuthException('Your session has ended. Log in again.');
    }
    try {
      return await _session(user, forceRefresh: true);
    } on FirebaseAuthException {
      throw AuthException('Your session has ended. Log in again.');
    }
  }

  Future<void> logout() => _auth.signOut();

  // ---- Forgot PIN / password (an admin approves, then a code is texted) ----

  /// Flags the request for the admin. The answer is the same whether or not the account exists.
  Future<void> requestReset({String? phone, String? email}) async {
    final res = await _post('/auth/reset/request', _who(phone, email));
    if (res.statusCode != 200) {
      throw AuthException('Could not send the request. Try again.');
    }
  }

  /// The code from the SMS; returns the short-lived reset token for [completeReset].
  Future<String> verifyResetCode({
    String? phone,
    String? email,
    required String code,
  }) async {
    final res = await _post('/auth/reset/verify', {
      ..._who(phone, email),
      'code': code.trim(),
    });
    if (res.statusCode != 200) {
      throw AuthException(
        'That code is not right or has expired. Check the SMS, or ask again.',
      );
    }
    return (jsonDecode(res.body) as Map)['resetToken'] as String;
  }

  Future<void> completeReset(
    String resetToken, {
    String? pin,
    String? password,
  }) async {
    final res = await _post('/auth/reset/complete', {
      'resetToken': resetToken,
      'pin': ?pin,
      'password': ?password,
    });
    if (res.statusCode == 400 && res.body.contains('no_email_on_account')) {
      throw AuthException('This account has no email, so it has no password.');
    }
    if (res.statusCode != 200) {
      throw AuthException('The reset has expired. Start again.');
    }
  }

  Map<String, String> _who(String? phone, String? email) => email != null
      ? {'email': email.trim()}
      : {'phone': normalizePhone(phone ?? '')};

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on Exception {
      throw AuthException(
        'Cannot reach the server. Check your connection and try again.',
      );
    }
  }

  Future<Session> _signedIn(Future<UserCredential> Function() signIn) async {
    try {
      final user = (await signIn()).user;
      if (user == null) throw AuthException('Sign-in failed. Try again.');
      return await _session(user);
    } on FirebaseAuthException catch (e) {
      throw _friendly(e);
    }
  }

  Future<Session> _session(User user, {bool forceRefresh = false}) async {
    final token = await user.getIdTokenResult(forceRefresh);
    final claims = token.claims ?? const {};
    return Session(
      accessToken: token.token ?? '',
      userId: user.uid,
      fullName: user.displayName ?? '',
      role: claims['role'] as String? ?? 'chw',
      healthCenterId: claims['hc'] as String?,
    );
  }
}

/// Rwandan numbers typed locally (07..., 7...) become +2507...; anything already international stays.
String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('250')) return '+$digits';
  if (digits.startsWith('0')) return '+250${digits.substring(1)}';
  return '+250$digits';
}

/// Firebase's error codes as messages a CHW can act on.
AuthException _friendly(Object e) {
  if (e is AuthException) return e;
  final code = e is FirebaseAuthException ? e.code : '';
  return AuthException(switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => 'Wrong email or password.',
    // Sign-up is switched off, so an unknown number cannot make an account.
    'admin-restricted-operation' =>
      'This phone number has no HealthBridge account. Ask your admin.',
    // Firebase's SMS region policy does not allow this number's country (or phone sign-in is off).
    'operation-not-allowed' => 'Sign-in by SMS code is not available for this number. Use your PIN, or ask your admin.',
    'user-disabled' => 'This account has been switched off. Ask your admin.',
    'invalid-phone-number' => 'Check the phone number.',
    'invalid-verification-code' => 'That code is not right. Check the SMS.',
    'session-expired' ||
    'code-expired' => 'The code has expired. Send a new one.',
    'too-many-requests' ||
    'quota-exceeded' => 'Too many attempts. Wait a while, then try again.',
    'network-request-failed' =>
      'Cannot reach the server. Check your connection and try again.',
    _ => 'Sign-in failed. Try again.',
  });
}

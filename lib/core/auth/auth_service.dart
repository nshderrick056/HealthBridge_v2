import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _apiUrlOverride = String.fromEnvironment('API_URL');

/// `--dart-define=API_URL=...` wins. Otherwise the dev server on this PC: the Android emulator
/// reaches it at 10.0.2.2, a browser at localhost.
final apiUrl = _apiUrlOverride.isNotEmpty
    ? _apiUrlOverride
    : (kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000');

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    this.healthCenterId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String? healthCenterId;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'fullName': fullName,
    'healthCenterId': healthCenterId,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    userId: j['userId'] as String,
    fullName: j['fullName'] as String,
    healthCenterId: j['healthCenterId'] as String?,
  );
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Login against POST /auth/login. Phone + PIN (4-6 digits) for CHWs, or email + password.
class AuthService {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? apiUrl,
       _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;
  static const _key = 'session';

  Future<Session> login(String id, String secret) async {
    final byEmail = id.contains('@');
    final body = byEmail
        ? {'email': id.trim(), 'password': secret}
        : {'phone': id.trim(), 'pin': secret};
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on Exception {
      throw AuthException(
        'Cannot reach the server. Check your connection and try again.',
      );
    }
    if (res.statusCode == 429) {
      throw AuthException('Too many attempts. Try again in 15 minutes.');
    }
    if (res.statusCode != 200) throw AuthException('Wrong ID or password.');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final user = j['user'] as Map<String, dynamic>;
    final session = Session(
      accessToken: j['accessToken'] as String,
      refreshToken: j['refreshToken'] as String,
      userId: user['id'] as String,
      fullName: user['fullName'] as String,
      healthCenterId: user['healthCenterId'] as String?,
    );
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    return session;
  }

  /// A new 15-minute access token from the 30-day refresh token. Network errors propagate (the caller
  /// retries later); a refused refresh throws [AuthException] and the CHW has to log in again.
  Future<Session> refresh(Session s) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refreshToken': s.refreshToken}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw AuthException('Your session has expired. Log in again.');
    }
    final next = Session(
      accessToken: (jsonDecode(res.body) as Map)['accessToken'] as String,
      refreshToken: s.refreshToken,
      userId: s.userId,
      fullName: s.fullName,
      healthCenterId: s.healthCenterId,
    );
    await _storage.write(key: _key, value: jsonEncode(next.toJson()));
    return next;
  }

  /// The saved session, so the CHW stays signed in while offline.
  Future<Session?> restore() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> logout() => _storage.delete(key: _key);
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

/// A refused or failed call to the HealthBridge API. [code] is the server's error code
/// (`invalid_transition`, `phone_or_email_taken`, ...), or `network` when it could not be reached.
class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// JSON calls to the HealthBridge API as the signed-in user (supervisor and admin screens). Sends the
/// Firebase ID token; when it has expired, refreshes it once and repeats the call.
class ApiClient {
  ApiClient({
    required this.auth,
    required this.session,
    required this.onSession,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AuthService auth;
  final Session? Function() session;
  final void Function(Session) onSession;
  final http.Client _client;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _call('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      _call('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Object body) =>
      _call('PATCH', path, body: body);

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    var s = session();
    if (s == null) throw ApiException(401, 'signed_out');
    var res = await _send(method, path, s, body, query);
    if (res.statusCode == 401) {
      s = await auth.refresh(s);
      onSession(s);
      res = await _send(method, path, s, body, query);
    }
    final json = res.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, json['error'] as String? ?? 'error');
    }
    return json;
  }

  Future<http.Response> _send(
    String method,
    String path,
    Session s,
    Object? body,
    Map<String, String>? query,
  ) async {
    final req = http.Request(
      method,
      Uri.parse('${auth.baseUrl}$path').replace(queryParameters: query),
    );
    req.headers['authorization'] = 'Bearer ${s.accessToken}';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      );
    } on Exception {
      throw ApiException(0, 'network');
    }
  }
}

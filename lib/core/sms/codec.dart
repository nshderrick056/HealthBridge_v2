// Urgent-alert SMS codec (Backend Schema §3). Must stay byte-identical to server/src/sms/codec.ts;
// shared/sms-vectors.json is checked by both test suites.
//
//   one part:  HB1 <device> <base64(nonce[12] | ciphertext | tag[16])>
//   two parts: HB1 <device> 1/2 <first half of base64>   and   HB1 <device> 2/2 <second half>
//
// AES-256-GCM with the header "HB1 <device>" as associated data, so a body cannot be re-sent under
// another device ID.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const smsMax = 160;
const _version = 'HB1';
const _nonceLen = 12;
const _tagLen = 16;

final _id = RegExp(r'^[A-Z0-9]{2,10}$');
final _shortCode = RegExp(r'^[0-9a-f]{8}$');
final _time = RegExp(r'^\d{10}$');
final _sign = RegExp(r'^[A-Z]{2}$');
final _vital = RegExp(r'^[A-Z][0-9.]{1,6}$');
final _smsRe = RegExp(r'^HB1 ([A-Z0-9]{2,10}) (?:([12])/2 )?([A-Za-z0-9+/=]+)$');
const _visitLetters = {'M', 'C', 'L', 'N'};

final _aes = AesGcm.with256bits();

class CodecException implements Exception {
  const CodecException(this.message);
  final String message;

  @override
  String toString() => 'CodecException: $message';
}

void _check(bool ok, String what) {
  if (!ok) throw CodecException('invalid $what');
}

class AlertFields {
  const AlertFields({
    required this.shortCode,
    required this.patient,
    required this.type,
    required this.time,
    this.signs = const [],
    this.vitals = const [],
  });

  /// First 8 hex characters of the visit UUID.
  final String shortCode;

  /// Patient short ID, never a name.
  final String patient;

  /// M maternal, C child, L malaria, N nutrition.
  final String type;

  /// YYMMDDHHmm, phone time.
  final String time;
  final List<String> signs;

  /// Type-specific vitals such as T389 (38.9 °C) or G32 (32 weeks).
  final List<String> vitals;
}

void _checkFields(AlertFields f) {
  _check(_shortCode.hasMatch(f.shortCode), 'short code');
  _check(_id.hasMatch(f.patient), 'patient');
  _check(_visitLetters.contains(f.type), 'visit type');
  _check(_time.hasMatch(f.time), 'time');
  _check(f.signs.every(_sign.hasMatch), 'sign');
  _check(f.vitals.every(_vital.hasMatch), 'vital');
}

String encodePlaintext(AlertFields f) {
  _checkFields(f);
  return ['A', f.shortCode, f.patient, f.type, f.time, f.signs.join(','), ...f.vitals].join(';');
}

AlertFields decodePlaintext(String text) {
  final p = text.split(';');
  _check(p.length >= 6 && p[0] == 'A', 'plaintext');
  final f = AlertFields(
    shortCode: p[1],
    patient: p[2],
    type: p[3],
    time: p[4],
    signs: p[5].isEmpty ? const [] : p[5].split(','),
    vitals: p.sublist(6),
  );
  _checkFields(f);
  return f;
}

/// Encrypts and splits into one or two SMS texts of at most 160 characters each.
Future<List<String>> seal({
  required List<int> key,
  required String deviceId,
  required String plaintext,
  List<int>? nonce,
}) async {
  nonce ??= _randomBytes(_nonceLen);
  _check(key.length == 32, 'key');
  _check(nonce.length == _nonceLen, 'nonce');
  _check(_id.hasMatch(deviceId), 'device');
  final header = '$_version $deviceId';
  final box = await _aes.encrypt(
    utf8.encode(plaintext),
    secretKey: SecretKey(key),
    nonce: nonce,
    aad: utf8.encode(header),
  );
  final body = base64.encode([...nonce, ...box.cipherText, ...box.mac.bytes]);

  final single = '$header $body';
  if (single.length <= smsMax) return [single];
  final half = (body.length / 2).ceil();
  final parts = [body.substring(0, half), body.substring(half)];
  final out = [for (var i = 0; i < 2; i++) '$header ${i + 1}/2 ${parts[i]}'];
  _check(out.every((p) => p.length <= smsMax), 'length (payload too long for two SMS)');
  return out;
}

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

class ParsedSms {
  const ParsedSms(this.deviceId, this.part, this.body);
  final String deviceId;

  /// 1 or 2 for a two-part message, null for a single SMS.
  final int? part;
  final String body;
}

/// Reads the clear header. Null if it is not a HealthBridge alert SMS.
ParsedSms? parseSms(String text) {
  final m = _smsRe.firstMatch(text.trim());
  if (m == null) return null;
  return ParsedSms(m[1]!, m[2] == null ? null : int.parse(m[2]!), m[3]!);
}

class OpenedSms {
  const OpenedSms(this.deviceId, this.nonce, this.plaintext);
  final String deviceId;
  final Uint8List nonce;
  final String plaintext;
}

/// Reassembles (parts may arrive in any order), verifies and decrypts. Throws [CodecException].
Future<OpenedSms> openSms(List<int> key, List<String> texts) async {
  _check(key.length == 32, 'key');
  final parsed = texts.map(parseSms).toList();
  _check(parsed.isNotEmpty && parsed.every((p) => p != null), 'sms');
  final parts = parsed.cast<ParsedSms>();
  final deviceId = parts.first.deviceId;
  _check(parts.every((p) => p.deviceId == deviceId), 'device');

  final String body;
  if (parts.length == 1 && parts.first.part == null) {
    body = parts.first.body;
  } else {
    _check(parts.length == 2, 'part count');
    final s = [...parts]..sort((a, b) => (a.part ?? 0).compareTo(b.part ?? 0));
    _check(s[0].part == 1 && s[1].part == 2, 'parts');
    body = s[0].body + s[1].body;
  }

  final Uint8List raw;
  try {
    raw = base64.decode(body);
  } on FormatException {
    throw const CodecException('invalid body');
  }
  _check(base64.encode(raw) == body && raw.length > _nonceLen + _tagLen, 'body');
  final nonce = raw.sublist(0, _nonceLen);
  try {
    final clear = await _aes.decrypt(
      SecretBox(
        raw.sublist(_nonceLen, raw.length - _tagLen),
        nonce: nonce,
        mac: Mac(raw.sublist(raw.length - _tagLen)),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode('$_version $deviceId'),
    );
    return OpenedSms(deviceId, nonce, utf8.decode(clear));
  } on SecretBoxAuthenticationError {
    throw const CodecException('authentication failed');
  }
}

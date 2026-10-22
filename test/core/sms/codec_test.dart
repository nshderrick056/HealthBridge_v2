import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/sms/codec.dart';

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

AlertFields _fields(Map<String, dynamic> j) => AlertFields(
  shortCode: j['shortCode'],
  patient: j['patient'],
  type: j['type'],
  time: j['time'],
  signs: List<String>.from(j['signs']),
  vitals: List<String>.from(j['vitals']),
);

void main() {
  // Shared with server/test/sms-codec.test.ts: both languages must produce and accept exactly these.
  final vectors = jsonDecode(
    File('shared/sms-vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final key = _hex(vectors['key']);

  group('shared vectors', () {
    for (final v in (vectors['valid'] as List).cast<Map<String, dynamic>>()) {
      test('seals and opens: ${v['name']}', () async {
        final expected = List<String>.from(v['sms']);
        expect(encodePlaintext(_fields(v['fields'])), v['plaintext']);
        final decoded = decodePlaintext(v['plaintext']);
        expect(encodePlaintext(decoded), v['plaintext']);

        final sms = await seal(
          key: key,
          deviceId: v['deviceId'],
          plaintext: v['plaintext'],
          nonce: _hex(v['nonce']),
        );
        expect(sms, expected);
        expect(sms.every((s) => s.length <= smsMax), isTrue);

        final opened = await openSms(
          key,
          expected.reversed.toList(),
        ); // parts may arrive out of order
        expect(opened.deviceId, v['deviceId']);
        expect(opened.nonce, _hex(v['nonce']));
        expect(opened.plaintext, v['plaintext']);
      });
    }

    for (final r
        in (vectors['rejected'] as List).cast<Map<String, dynamic>>()) {
      test('rejects: ${r['name']}', () {
        expect(
          openSms(key, List<String>.from(r['sms'])),
          throwsA(isA<CodecException>()),
        );
      });
    }

    test('rejects malformed plaintext', () {
      for (final p in (vectors['badPlaintext'] as List).cast<String>()) {
        expect(
          () => decodePlaintext(p),
          throwsA(isA<CodecException>()),
          reason: p,
        );
      }
    });
  });

  group('codec', () {
    final plaintext = (vectors['valid'] as List).first['plaintext'] as String;

    test('uses a fresh random nonce by default', () async {
      final a = await seal(key: key, deviceId: 'D0042', plaintext: plaintext);
      final b = await seal(key: key, deviceId: 'D0042', plaintext: plaintext);
      expect(a, isNot(b));
      expect((await openSms(key, a)).plaintext, plaintext);
    });

    test('fails with the wrong key', () async {
      final sms = await seal(key: key, deviceId: 'D0042', plaintext: plaintext);
      expect(openSms(List.filled(32, 7), sms), throwsA(isA<CodecException>()));
    });

    test('refuses payloads too long for two SMS', () {
      expect(
        seal(key: key, deviceId: 'D0042', plaintext: 'A;'.padRight(300, 'x')),
        throwsA(isA<CodecException>()),
      );
    });

    test('parses the clear header', () {
      final p = parseSms('HB1 D0042 2/2 abcd')!;
      expect([p.deviceId, p.part, p.body], ['D0042', 2, 'abcd']);
      expect(parseSms('HB OK 7f3c9a21'), isNull);
    });
  });
}

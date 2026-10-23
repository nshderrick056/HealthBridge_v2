import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/urgent/urgent_sender.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sender selection', () {
    test('the managed build sends SMS itself and reads the ack', () {
      final s = senderForFlavor('managed');
      expect(s, isA<DirectSmsSender>());
      expect(s.channel, 'sms_direct');
      expect(s.readsAcks, isTrue);
    });

    test('the store build, and a run without a flavour, use the composer', () {
      for (final flavor in ['store', null]) {
        final s = senderForFlavor(flavor);
        expect(s, isA<ComposerSender>(), reason: '$flavor');
        expect(s.channel, 'sms_composer');
        expect(s.readsAcks, isFalse);
      }
    });
  });

  group('ComposerSender', () {
    test('sms: link keeps the base64 body intact (no + for spaces)', () {
      const body = 'HB1 D000042 ab+/cd==';
      final uri = smsUri('+250780000100', body);
      expect(uri.scheme, 'sms');
      expect(uri.path, '+250780000100');
      expect(uri.toString(), contains('%2B'));
      expect(uri.queryParameters['body'], body);
    });

    test('opens the SMS app once per part, the second after the CHW is back', () async {
      final events = <String>[];
      final sender = ComposerSender(
        launch: (u) async {
          events.add('open ${u.queryParameters['body']}');
          return true;
        },
        backInApp: () async => events.add('back'),
      );
      await sender.send('+250780000100', ['part 1', 'part 2']);
      expect(events, ['open part 1', 'back', 'open part 2']);
    });

    test('fails when no SMS app can open the link', () async {
      final sender = ComposerSender(launch: (_) async => false);
      expect(
        () => sender.send('+250780000100', ['x']),
        throwsA(isA<UrgentSendException>()),
      );
    });
  });

  group('DirectSmsSender', () {
    const channel = MethodChannel('rw.healthbridge/sms.test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late PlatformException? sendError;

    setUp(() {
      calls = [];
      sendError = null;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'send' && sendError != null) throw sendError!;
        if (call.method == 'takeAcks') return ['7f3c9a21'];
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('hands the number and the parts to the Kotlin channel', () async {
      await DirectSmsSender(channel: channel).send('+250780000100', ['a', 'b']);
      expect(calls.single.method, 'send');
      expect(calls.single.arguments, {
        'to': '+250780000100',
        'parts': ['a', 'b'],
      });
    });

    test('falls back to the composer when SMS permission is refused', () async {
      final opened = <Uri>[];
      sendError = PlatformException(code: 'permission');
      final sender = DirectSmsSender(
        channel: channel,
        fallback: ComposerSender(
          launch: (u) async {
            opened.add(u);
            return true;
          },
        ),
      );
      await sender.send('+250780000100', ['a']);
      expect(opened.single.queryParameters['body'], 'a');
    });

    test('a radio failure is an error, and so is a missing gateway number', () async {
      sendError = PlatformException(code: 'not_sent');
      final sender = DirectSmsSender(channel: channel);
      await expectLater(
        sender.send('+250780000100', ['a']),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        sender.send('', ['a']),
        throwsA(isA<UrgentSendException>()),
      );
    });

    test('takes the acks the receiver collected', () async {
      expect(await DirectSmsSender(channel: channel).takeAcks(), ['7f3c9a21']);
    });
  });
}

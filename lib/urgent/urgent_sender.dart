import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:url_launcher/url_launcher.dart';

/// Where the urgent SMS goes: the gateway's number (Africa's Talking shortcode or long number).
/// Set per build with `--dart-define=SMS_GATEWAY_NUMBER=...`.
const smsGatewayNumber = String.fromEnvironment('SMS_GATEWAY_NUMBER');

class UrgentSendException implements Exception {
  const UrgentSendException(this.message);
  final String message;

  @override
  String toString() => 'UrgentSendException: $message';
}

/// Hands the sealed alert SMS to the phone (TRD §3 rule 1). One implementation per build flavour.
abstract class UrgentSender {
  /// Stored on the dispatch row: `sms_composer` or `sms_direct`.
  String get channel;

  /// True when the sender reads the "HB OK" ack itself. Otherwise the CHW confirms it by hand.
  bool get readsAcks;

  /// Throws when the SMS could not be handed over, so the CHW is offered Resend and Call at once.
  Future<void> send(String to, List<String> parts);

  /// Asks for whatever the sender needs up front (the managed build's SMS permission).
  Future<void> prepare() async {}

  /// Short codes from ack SMS received since the last call.
  Future<List<String>> takeAcks() async => const [];

  /// [onAck] runs when an ack SMS arrives while the app is open.
  void onAck(void Function() onAck) {}
}

/// Google Play forbids SEND_SMS outside default SMS apps, so only the managed build sends by itself.
UrgentSender senderForFlavor(String? flavor) =>
    flavor == 'managed' ? DirectSmsSender() : ComposerSender();

/// `sms:` link with the body percent-encoded: query encoding would turn spaces into '+', which SMS
/// apps show literally, and the base64 body has '+' and '/' of its own.
Uri smsUri(String to, String body) =>
    Uri.parse('sms:$to?body=${Uri.encodeComponent(body)}');

/// Store build: opens the SMS app pre-filled and the CHW taps Send. A two-part alert opens it a
/// second time once the CHW is back in HealthBridge.
class ComposerSender extends UrgentSender {
  ComposerSender({
    Future<bool> Function(Uri)? launch,
    Future<void> Function()? backInApp,
  }) : _launch = launch ?? launchUrl,
       _backInApp = backInApp ?? _nextResume;

  final Future<bool> Function(Uri) _launch;
  final Future<void> Function() _backInApp;

  @override
  String get channel => 'sms_composer';

  @override
  bool get readsAcks => false;

  @override
  Future<void> send(String to, List<String> parts) async {
    for (final (i, text) in parts.indexed) {
      if (i > 0) await _backInApp();
      if (!await _launch(smsUri(to, text))) {
        throw const UrgentSendException('no SMS app to open');
      }
    }
  }

  static Future<void> _nextResume() {
    final back = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        back.complete();
      },
    );
    return back.future;
  }
}

/// Managed build: sends through the Kotlin channel in `android/app/src/managed/kotlin/`, which also
/// collects the "HB OK <code>" acks. No SMS plugin, so SEND_SMS never reaches the store manifest.
class DirectSmsSender extends UrgentSender {
  DirectSmsSender({
    this._channel = const MethodChannel('rw.healthbridge/sms'),
    UrgentSender? fallback,
    this.radioTimeout = const Duration(seconds: 60),
  }) : _fallback = fallback ?? ComposerSender();

  final MethodChannel _channel;
  final UrgentSender _fallback;

  /// How long to wait for the radio to report the SMS as sent.
  final Duration radioTimeout;

  @override
  String get channel => 'sms_direct';

  @override
  bool get readsAcks => true;

  @override
  Future<void> prepare() => _channel.invokeMethod<bool>('requestPermission');

  @override
  Future<void> send(String to, List<String> parts) async {
    if (to.isEmpty) {
      throw const UrgentSendException('SMS_GATEWAY_NUMBER is not set');
    }
    try {
      await _channel
          .invokeMethod<void>('send', {'to': to, 'parts': parts})
          .timeout(radioTimeout);
    } on PlatformException catch (e) {
      // SMS permission refused: the CHW can still send it from the SMS app.
      if (e.code == 'permission') return _fallback.send(to, parts);
      rethrow;
    }
  }

  @override
  Future<List<String>> takeAcks() async =>
      await _channel.invokeListMethod<String>('takeAcks') ?? const [];

  @override
  void onAck(void Function() onAck) =>
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'ack') onAck();
      });
}

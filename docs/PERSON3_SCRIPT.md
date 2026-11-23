# Person 3: the script, snippet by snippet (9:00 to 11:00)

Topic: urgent alerts, the offline SMS fallback, sync, and the shared-state update. About 2 minutes, roughly 270 spoken words. The team script is in [VIDEO_SCRIPTS.md](VIDEO_SCRIPTS.md). Line numbers below were read at commit `fa712c6`.

**Assignment question you answer:** state management in action across components.

**Before you record:** the offline SMS path was not phone-tested on the Firebase build. Rehearse it. If it fails on the day, show the online path and the Sync screen, and say the codec is covered by shared test vectors (`shared/sms-vectors.json`).

## Order and timing

| Time | Show | Say (the short version) |
|---|---|---|
| 9:00 | `lib/presentation/home/home_screen.dart`, lines 30-33 | one provider, many widgets |
| 9:25 | same file, lines 214-220 | the card reacts |
| 9:40 | `lib/urgent/urgent_dispatcher.dart`, lines 67-77 | internet first, then SMS |
| 10:05 | same file, lines 119-122 | only our server can confirm |
| 10:25 | `lib/core/sms/codec.dart`, lines 214-226 | the HMAC tag |
| 10:50 | spoken only | merge and background sync |

## 1. One provider, several widgets: `home_screen.dart` lines 30-33 (25 seconds)

```dart
    final online = ref.watch(isOnlineProvider);
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final dispatches = ref.watch(allDispatchesProvider).value ?? const [];
```

**Say:** "I did urgent alerts and sync. The Home screen watches a few providers. `allDispatchesProvider` is a StreamProvider over the local database, so whenever an alert's state changes, every widget that watches it rebuilds. The red alert card and the Urgent-today stat card you saw both read from here: one source of truth, no manual refresh. `isOnlineProvider` drives the connection pill the same way."

**Brief notes:** `ref.watch` re-runs the build when the value changes. `.value ?? const []` means "empty list while loading", so the screen never shows an error flash.

## 2. The card follows the state: `home_screen.dart` lines 214-220 (15 seconds)

```dart
    final alert = switch (state) {
      DispatchState.confirmed => 'the health centre has the alert',
      DispatchState.sentSms ||
      DispatchState.unconfirmed => 'alert sent by SMS, not confirmed yet',
      DispatchState.sending => 'alert is sending',
      null => 'alert not sent yet',
    };
```

**Say:** "The card's wording is just a `switch` on the dispatch state. When the state moves from sending to confirmed, the text changes by itself."

**Brief notes:** a `switch` expression over an enum must cover every case, so adding a new state forces a compile error here until it is handled.

## 3. Internet first, SMS second: `urgent_dispatcher.dart` lines 67-77 (25 seconds)

```dart
  Future<void> send(String visitId) async {
    await _repo.start(visitId);
    try {
      await _postAlert(visitId).timeout(internetTimeout);
      await _repo.updateState(visitId, DispatchState.confirmed);
    } on Exception {
      await sendSms(visitId);
    }
  }
```

**Say:** "`send` marks the alert as started, then tries the internet with a ten-second timeout. If that works, the visit and alert reach Firestore together and the state becomes confirmed. If it fails or times out, we fall back to SMS. The SMS is encrypted with AES-256-GCM, using the header as associated data, so a message cannot be replayed under another device. After ten minutes without an acknowledgement, the card offers Resend and Call."

**Brief notes:** `internetTimeout` defaults to ten seconds (a constructor argument, so tests can shorten it). `sendSms` is on line 79 and calls `seal(...)` from `codec.dart` (line 109).

## 4. Only our server can confirm: `urgent_dispatcher.dart` lines 119-122 (20 seconds)

```dart
      final parts = ack.split(' ');
      if (parts.length != 2) continue; // unsigned or malformed
      if (parts[1] != await ackTag(device.smsKey, parts[0])) continue;
      await acknowledge(parts[0]);
```

**Say:** "When a reply arrives, it must be the short code plus a tag. We recompute the tag with this device's key and compare. If it does not match, we ignore it, so nobody who learns a short code can fake a confirmation."

**Brief notes:** `continue` skips to the next reply in the loop. `acknowledge` is what flips the state to confirmed.

## 5. The HMAC tag: `codec.dart` lines 214-226 (25 seconds)

```dart
/// The tag the server puts on an acknowledgement, `HB OK <code> <tag>`: the first 12 hex of
/// HMAC-SHA256 over "HB OK <code>" with the device's SMS key. Only a reply carrying the right tag
/// confirms an alert, so a stranger who learns a short code cannot fake one.
Future<String> ackTag(List<int> key, String shortCode) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('HB OK $shortCode'),
    secretKey: SecretKey(key),
  );
  return mac.bytes
      .take(6)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
```

**Say:** "This is the tag. It is an HMAC-SHA256 of the text 'HB OK' plus the code, keyed with the device's own SMS key, and we keep the first six bytes, twelve hex characters, to fit in an SMS. The server computes the same thing, so a matching tag proves it came from the server."

**Brief notes:** the Dart codec and the TypeScript codec must produce identical bytes; `shared/sms-vectors.json` is tested by both.

## 6. Merge and background sync (10 seconds, spoken only)

**Say:** "When the phone is back online, the full visit uploads and the server merges it into the same case as the SMS one, so the supervisor sees one case, not two. The sync engine drains the outbox, and workmanager runs it in the background."

## Hand-off

"The alert has left the phone; [Name] shows what the supervisor does with it."

## If you run long

Drop section 5 (say only "an HMAC tag"), then the second half of section 1.

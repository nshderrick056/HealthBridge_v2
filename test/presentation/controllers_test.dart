import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/core/settings/settings.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/providers.dart';
import 'package:health_bridge/presentation/auth/login_controller.dart';
import 'package:health_bridge/presentation/patients/patients_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<ProviderContainer> container({AuthService? auth}) async =>
      ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          if (auth != null) authServiceProvider.overrideWithValue(auth),
        ],
      );

  group('settings', () {
    test('start with the defaults', () async {
      final s = (await container()).read(settingsProvider);
      expect(s.textSize, TextSize.normal);
      expect(s.defaultVisitType, VisitType.maternal);
      expect(s.rememberLogin, isFalse);
      expect(s.savedLoginId, isNull);
    });

    test('are restored by the next launch', () async {
      final first = await container();
      final settings = first.read(settingsProvider.notifier);
      await settings.setTextSize(TextSize.extraLarge);
      await settings.setDefaultVisitType(VisitType.child);
      await settings.setRememberLogin(true);
      await settings.loggedInAs(' +250780000101 ');

      // A new container reads the same stored preferences, like a relaunch.
      final s = (await container()).read(settingsProvider);
      expect(s.textSize, TextSize.extraLarge);
      expect(s.defaultVisitType, VisitType.child);
      expect(s.rememberLogin, isTrue);
      expect(s.savedLoginId, '+250780000101');
    });

    test('turning "remember" off forgets the saved ID', () async {
      final c = await container();
      final settings = c.read(settingsProvider.notifier);
      await settings.setRememberLogin(true);
      await settings.loggedInAs('+250780000101');
      await settings.setRememberLogin(false);

      expect(c.read(settingsProvider).savedLoginId, isNull);
      expect((await container()).read(settingsProvider).savedLoginId, isNull);
    });

    test('an ID is not kept when "remember" is off', () async {
      final c = await container();
      await c.read(settingsProvider.notifier).loggedInAs('+250780000101');
      expect((await container()).read(settingsProvider).savedLoginId, isNull);
    });
  });

  group('login', () {
    AuthService auth(int status) => AuthService(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          status == 200
              ? jsonEncode({
                  'accessToken': 'a',
                  'refreshToken': 'r',
                  'user': {'id': 'u1', 'fullName': 'Claudine Mukamana'},
                })
              : '{"error":"invalid_credentials"}',
          status,
        ),
      ),
    );

    test('a wrong PIN shows the error and stays signed out', () async {
      final c = await container(auth: auth(401));
      c.listen(loginControllerProvider, (_, _) {});
      await c
          .read(loginControllerProvider.notifier)
          .submit('+250780000101', '0000');

      expect(c.read(loginControllerProvider).error, 'Wrong ID or password.');
      expect(c.read(loginControllerProvider).busy, isFalse);
      expect(c.read(sessionProvider), isNull);
    });

    test('success signs in and remembers the ID when asked', () async {
      final c = await container(auth: auth(200));
      await c.read(settingsProvider.notifier).setRememberLogin(true);
      c.listen(loginControllerProvider, (_, _) {});
      await c
          .read(loginControllerProvider.notifier)
          .submit('+250780000101', '1234');

      expect(c.read(sessionProvider)?.fullName, 'Claudine Mukamana');
      expect(c.read(settingsProvider).savedLoginId, '+250780000101');
    });
  });

  test('the patients search and filter keep each other', () async {
    final c = await container();
    c.listen(patientsQueryProvider, (_, _) {});
    final q = c.read(patientsQueryProvider.notifier);
    q.search('nyamata');
    q.filterBy(PatientFilter.urgent);
    q.search('uwase');

    final state = c.read(patientsQueryProvider);
    expect(state.text, 'uwase');
    expect(state.filter, PatientFilter.urgent);
  });
}

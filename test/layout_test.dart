import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/core/settings/settings.dart';
import 'package:health_bridge/core/theme/app_theme.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/providers.dart';
import 'package:health_bridge/presentation/auth/login_screen.dart';
import 'package:health_bridge/presentation/patients/patient_profile_screen.dart';
import 'package:health_bridge/presentation/patients/register_patient_screen.dart';
import 'package:health_bridge/presentation/record/record_saved_screen.dart';
import 'package:health_bridge/presentation/record/sms_alert_sent_screen.dart';
import 'package:health_bridge/presentation/sync/sync_status_screen.dart';
import 'package:health_bridge/presentation/settings/settings_screen.dart';
import 'package:health_bridge/presentation/shell/app_shell.dart';
import 'package:health_bridge/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every main screen, on a small phone, a large phone and in landscape: any RenderFlex overflow fails.
// (size, text scale): 0.55 brings the wide test font (Ahem) close to Inter; 0.72 is that times the
// Settings screen's "Extra large" (1.3).
const _sizes = {
  'small phone (320x568)': (Size(320, 568), 0.55),
  'large phone (430x932)': (Size(430, 932), 0.55),
  'landscape (844x390)': (Size(844, 390), 0.55),
  'landscape, extra large text': (Size(844, 390), 0.72),
};

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await db
        .into(db.patients)
        .insert(
          PatientsCompanion.insert(
            id: 'p1',
            shortId: 'P000001',
            fullName: 'Mukamana Claudine Uwimana',
            village: 'Nyamata',
            sex: const Value('F'),
            ageEstimate: const Value(32),
            consentAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.visits)
        .insert(
          VisitsCompanion.insert(
            id: 'v1',
            shortCode: '7f3c9a21',
            patientId: 'p1',
            type: VisitType.maternal,
            recordedAt: now,
            isUrgent: const Value(true),
          ),
        );
    await db
        .into(db.urgentDispatch)
        .insert(
          UrgentDispatchCompanion.insert(
            visitId: 'v1',
            channel: 'sms_composer',
            state: DispatchState.unconfirmed,
            sentAt: Value(now),
          ),
        );
  });

  Widget app(Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionProvider.overrideWith(
        (ref) => const Session(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'u1',
          fullName: 'Claudine Mukamana',
        ),
      ),
      syncNowProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp(theme: buildTheme(), home: home),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(db.close);
  }

  void screen(WidgetTester tester, (Size, double) setup) {
    final (size, textScale) = setup;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    group(name, () {
      testWidgets('every tab fits', (tester) async {
        screen(tester, size);
        await tester.pumpWidget(app(const AppShell()));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'Home');
        for (final tab in ['Patients', 'Record Visit', 'Alerts', 'Profile']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: tab);
        }
        await finish(tester);
      });

      for (final (label, page) in [
        ('login', const LoginScreen()),
        ('settings', const SettingsScreen()),
        ('register patient', const RegisterPatientScreen()),
        ('patient profile', const PatientProfileScreen(patientId: 'p1')),
        ('unconfirmed SMS alert', const SmsAlertSentScreen(visitId: 'v1')),
        ('visit saved', const RecordSavedScreen(visitId: 'v1')),
        ('sync status', const SyncStatusScreen()),
      ]) {
        testWidgets('$label fits', (tester) async {
          screen(tester, size);
          await tester.pumpWidget(app(page));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await finish(tester);
        });
      }
    });
  }
}

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/core/settings/settings.dart';
import 'package:health_bridge/core/theme/app_theme.dart';
import 'package:health_bridge/core/widgets/widgets.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/data/providers.dart';
import 'package:health_bridge/presentation/auth/login_screen.dart';
import 'package:health_bridge/presentation/record/sms_alert_sent_screen.dart';
import 'package:health_bridge/presentation/settings/settings_screen.dart';
import 'package:health_bridge/presentation/shell/app_shell.dart';
import 'package:health_bridge/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = Session(
  accessToken: 'a',
  userId: 'u1',
  fullName: 'Claudine Mukamana',
);

late SharedPreferences _prefs;

Widget _app(AppDatabase db, Widget home) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(_prefs),
    sessionProvider.overrideWith((ref) => _session),
    syncNowProvider.overrideWithValue(
      () async {},
    ), // no network in widget tests
  ],
  child: MaterialApp(theme: buildTheme(), home: home),
);

void main() {
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  // Real DB work completes in real time, so let it finish outside fake-async before settling the UI.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  // Unmount first so drift's stream-cleanup timers run down, then close the DB outside fake-async.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(db.close);
  }

  // flutter_test renders with the very wide Ahem font; shrink it so layouts fit as they do with Inter.
  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  Future<void> pumpShell(WidgetTester tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(_app(db, const AppShell()));
    await tester.pump();
  }

  testWidgets('summary cards grow instead of overflowing at full text size', (
    tester,
  ) async {
    // No text shrink here: wide Ahem glyphs wrap the labels, like a large system font would.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String label) => Expanded(
      child: SummaryCard(
        icon: Icons.person_outline,
        tint: HbColors.greenTint,
        color: HbColors.green,
        value: 12,
        label: label,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                SummaryRow(
                  children: [
                    card('Patients visited'),
                    const SizedBox(width: 8),
                    card('Follow-ups due'),
                    const SizedBox(width: 8),
                    card('Urgent'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final heights = tester
        .widgetList(find.byType(SummaryCard))
        .map((w) => tester.getSize(find.byWidget(w)).height)
        .toSet();
    expect(heights, hasLength(1)); // all three match the tallest
    expect(heights.single, greaterThan(100));
  });

  testWidgets('login asks for ID and password and validates them', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(_app(db, const LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('PIN'), findsWidgets);
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
    await finish(tester);
  });

  testWidgets('home shows the greeting, summary cards and the five-tab bar', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.textContaining('Claudine'), findsOneWidget);
    expect(find.text('Record new visit'), findsOneWidget);
    expect(find.text('Patients visited'), findsOneWidget);
    expect(find.text('No visits recorded yet.'), findsOneWidget);
    for (final tab in [
      'Home',
      'Patients',
      'Record Visit',
      'Alerts',
      'Profile',
    ]) {
      expect(find.text(tab), findsWidgets);
    }
    await finish(tester);
  });

  testWidgets('patients tab lists a registered patient and filters by search', (
    tester,
  ) async {
    await db
        .into(db.patients)
        .insert(
          PatientsCompanion.insert(
            id: 'p1',
            shortId: 'P000001',
            fullName: 'Uwase Marie',
            village: 'Nyamata',
            sex: const Value('F'),
            ageEstimate: const Value(32),
            consentAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    await pumpShell(tester);
    await tester.tap(find.text('Patients').last);
    await tester.pumpAndSettle();

    expect(find.text('Uwase Marie'), findsOneWidget);
    expect(find.text('32 years \u00B7 Female'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Uwase Marie'), findsNothing);
    expect(find.text('No patients match.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'recording a visit with a danger sign saves it as urgent and opens the urgent screen',
    (tester) async {
      await db
          .into(db.patients)
          .insert(
            PatientsCompanion.insert(
              id: 'p1',
              shortId: 'P000001',
              fullName: 'Uwase Marie',
              village: 'Nyamata',
              consentAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      await pumpShell(tester);
      await tester.tap(find.text('Record new visit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Uwase Marie'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Heavy bleeding'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Heavy bleeding'));
      await tester.pump();
      await tester.tap(find.text('Heavy bleeding'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Review visit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review visit'));
      await tester.pumpAndSettle();
      expect(find.text('Check details before submitting'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Submit visit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Submit visit'));
      await settle(tester);
      await settle(
        tester,
      ); // the next screen loads the visit with a second real-time query

      expect(find.text('Urgent case detected'), findsOneWidget);
      expect(find.text('Heavy bleeding'), findsOneWidget);
      final visits = (await tester.runAsync(() => db.select(db.visits).get()))!;
      expect(visits.single.isUrgent, isTrue);
      expect(visits.single.syncState, SyncState.queued);
      expect(
        (await tester.runAsync(() => db.select(db.outbox).get()))!,
        hasLength(1),
      );
      await finish(tester);
    },
  );

  Future<void> seedUrgent(String channel, DispatchState state) async {
    final now = DateTime.now();
    await db
        .into(db.patients)
        .insert(
          PatientsCompanion.insert(
            id: 'p1',
            shortId: 'P000001',
            fullName: 'Uwase Marie',
            village: 'Nyamata',
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
            channel: channel,
            state: state,
            sentAt: Value(now),
          ),
        );
  }

  testWidgets(
    'an unconfirmed SMS alert offers Resend and Call, and the store build can confirm it by hand',
    (tester) async {
      await seedUrgent('sms_composer', DispatchState.unconfirmed);
      phoneScreen(tester);
      await tester.pumpWidget(
        _app(db, const SmsAlertSentScreen(visitId: 'v1')),
      );
      await settle(tester);

      expect(find.text('SMS alert sent'), findsOneWidget);
      expect(find.text('No confirmation yet'), findsOneWidget);
      expect(find.text('Resend SMS'), findsOneWidget);
      expect(find.text('Call health centre'), findsOneWidget);

      await tester.ensureVisible(find.text('I got the confirmation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I got the confirmation'));
      await settle(tester);

      expect(find.text('Alert received by the health centre'), findsOneWidget);
      expect(find.text('Resend SMS'), findsNothing);
      expect(find.text('I got the confirmation'), findsNothing);
      final d = (await tester.runAsync(
        () => db.select(db.urgentDispatch).getSingle(),
      ))!;
      expect(d.state, DispatchState.confirmed);
      await finish(tester);
    },
  );

  Future<void> seedPatient() => db
      .into(db.patients)
      .insert(
        PatientsCompanion.insert(
          id: 'p1',
          shortId: 'P000001',
          fullName: 'Uwase Marie',
          village: 'Nyamata',
          sex: const Value('F'),
          ageEstimate: const Value(32),
          consentAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> openProfile(WidgetTester tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Patients').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uwase Marie'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing a patient saves, queues an upload and shows the change',
    (tester) async {
      await seedPatient();
      await openProfile(tester);

      await tester.tap(find.byTooltip('Edit patient'));
      await tester.pumpAndSettle();
      expect(find.text('Edit patient'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Uwase Marie'),
        'Uwase Marie-Claire',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '32'), 'abc');
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(
        find.text('Enter the age in whole years (0 to 130)'),
        findsOneWidget,
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'abc'), '33');
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(find.text('Uwase Marie-Claire'), findsOneWidget);
      final p = (await tester.runAsync(
        () => db.select(db.patients).getSingle(),
      ))!;
      expect(p.fullName, 'Uwase Marie-Claire');
      expect(p.ageEstimate, 33);
      expect(p.syncState, SyncState.queued);
      expect(
        (await tester.runAsync(() => db.select(db.outbox).get()))!,
        hasLength(1),
      );
      await finish(tester);
    },
  );

  testWidgets('archiving asks first, hides the patient and can be undone', (
    tester,
  ) async {
    await seedPatient();
    await openProfile(tester);

    await tester.tap(find.byTooltip('Archive patient'));
    await tester.pumpAndSettle();
    expect(find.text('Archive this patient?'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await settle(tester);

    expect(find.text('Uwase Marie archived'), findsOneWidget);
    expect(
      find.text('No patients yet. Register your first patient.'),
      findsOneWidget,
    );
    var p = (await tester.runAsync(() => db.select(db.patients).getSingle()))!;
    expect(p.archivedAt, isNotNull); // kept, not deleted

    await tester.tap(find.text('Undo'));
    await settle(tester);
    p = (await tester.runAsync(() => db.select(db.patients).getSingle()))!;
    expect(p.archivedAt, isNull);
    expect(find.text('Uwase Marie'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('settings are saved to SharedPreferences as they are changed', (
    tester,
  ) async {
    phoneScreen(tester);
    await tester.pumpWidget(_app(db, const SettingsScreen()));
    await tester.pump();

    await tester.tap(find.text('Large'));
    await tester.tap(find.text('Child Health'));
    await tester.ensureVisible(find.text('Remember my phone number'));
    await tester.pump();
    await tester.tap(find.text('Remember my phone number'));
    await tester.pump();

    expect(_prefs.getString('settings.textSize'), 'large');
    expect(_prefs.getString('settings.defaultVisitType'), 'child');
    expect(_prefs.getBool('settings.rememberLogin'), isTrue);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await finish(tester);
  });

  testWidgets('the login screen is pre-filled with a remembered ID', (
    tester,
  ) async {
    await _prefs.setBool('settings.rememberLogin', true);
    await _prefs.setString('settings.loginId', '+250780000101');
    phoneScreen(tester);
    await tester.pumpWidget(_app(db, const LoginScreen()));

    expect(find.text('+250780000101'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an alert confirmed over the internet shows no SMS actions', (
    tester,
  ) async {
    await seedUrgent('internet', DispatchState.confirmed);
    phoneScreen(tester);
    await tester.pumpWidget(_app(db, const SmsAlertSentScreen(visitId: 'v1')));
    await settle(tester);

    expect(find.text('Urgent alert sent'), findsOneWidget);
    expect(
      find.text('The alert reached the health centre over the internet.'),
      findsOneWidget,
    );
    for (final gone in [
      'Resend SMS',
      'Call health centre',
      'I got the confirmation',
      'Full patient record',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    await finish(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/api/api_client.dart';
import 'package:health_bridge/core/auth/auth_service.dart';
import 'package:health_bridge/core/theme/app_theme.dart';
import 'package:health_bridge/data/providers.dart';
import 'package:health_bridge/data/repositories/supervision_repository.dart';
import 'package:health_bridge/domain/entities/supervision.dart';
import 'package:health_bridge/presentation/admin/admin_screens.dart';
import 'package:health_bridge/presentation/supervisor/case_screen.dart';
import 'package:health_bridge/presentation/supervisor/inbox_screen.dart';

ApiClient _unused() => ApiClient(
  auth: AuthService(baseUrl: 'http://api.test'),
  session: () => null,
  onSession: (_) {},
);

class _FakeSupervision extends SupervisionRepository {
  _FakeSupervision() : super(_unused());
  final moves = <(String, AlertStatus, String?)>[];

  @override
  Future<List<AlertSummary>> alerts({String? status}) async => [
    AlertSummary.fromJson({
      'id': 'a1',
      'status': 'new',
      'channel': 'sms',
      'createdAt': '2026-11-15T08:00:00Z',
      'isPartial': true,
      'patient': {'shortId': 'P0412', 'name': null},
      'chw': {'name': 'Mukamana Alice'},
      'village': 'Gatare',
      'dangerSigns': ['Heavy bleeding'],
    }),
  ];

  @override
  Future<AlertDetail> alert(String id) async => AlertDetail.fromJson({
    'id': id,
    'status': 'escalated',
    'channel': 'internet',
    'next': ['follow_up', 'resolved'],
    'visit': {'shortCode': '7f3c9a21', 'type': 'maternal', 'answers': {}},
    'patient': {
      'shortId': 'P0412',
      'name': 'Uwase Marie',
      'village': 'Nyamata',
    },
    'chw': {'name': 'Mukamana Alice', 'phone': '+250780000501'},
    'dangerSigns': [
      {'code': 'HB', 'label': 'Heavy bleeding'},
    ],
    'events': [
      {'fromStatus': 'new', 'toStatus': 'escalated', 'actor': 'Grace'},
    ],
  });

  @override
  Future<void> setStatus(String id, AlertStatus status, {String? note}) async =>
      moves.add((id, status, note));
}

class _FakeAdmin extends AdminRepository {
  _FakeAdmin() : super(_unused());
  final approved = <String>[];

  @override
  Future<List<ResetRequest>> resetRequests() async => approved.isEmpty
      ? [
          ResetRequest.fromJson({
            'id': 'r1',
            'name': 'Mukamana Alice',
            'phone': '+250790218726',
            'role': 'chw',
          }),
        ]
      : [];

  @override
  Future<void> approve(String requestId) async => approved.add(requestId);
}

void main() {
  Future<void> pump(WidgetTester tester, Widget home, List overrides) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides],
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(body: home),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the inbox lists a case with its CHW, signs and SMS status', (
    tester,
  ) async {
    await pump(tester, const InboxScreen(), [
      supervisionRepositoryProvider.overrideWithValue(_FakeSupervision()),
    ]);
    expect(find.text('Patient P0412'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
    expect(find.text('Heavy bleeding'), findsOneWidget);
    expect(find.text('By SMS · full record not received yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the inbox's 10-second refresh timer run out after the screen has gone.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('a case offers only the allowed next steps and saves a move', (
    tester,
  ) async {
    final repo = _FakeSupervision();
    await pump(tester, const CaseScreen(alertId: 'a1'), [
      supervisionRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.text('Uwase Marie'), findsOneWidget);
    expect(find.text('Ask for follow-up'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    expect(find.text('Escalate'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Seen at the clinic');
    await tester.ensureVisible(find.text('Resolve'));
    await tester.tap(find.text('Resolve'));
    await tester.pump();
    expect(repo.moves.single, (
      'a1',
      AlertStatus.resolved,
      'Seen at the clinic',
    ));
  });

  testWidgets(
    'the admin approves a reset request, which then leaves the list',
    (tester) async {
      final repo = _FakeAdmin();
      await pump(tester, const ResetRequestsScreen(), [
        adminRepositoryProvider.overrideWithValue(repo),
      ]);
      expect(find.text('Mukamana Alice'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump();
      expect(repo.approved, ['r1']);
      expect(find.text('No one is waiting.'), findsOneWidget);
    },
  );
}

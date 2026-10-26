import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/core/widgets/widgets.dart';
import 'package:health_bridge/data/db.dart';
import 'package:health_bridge/data/models.dart';
import 'package:health_bridge/features/view_models.dart';

void main() {
  final now = DateTime.now();
  final patient = Patient(
    id: 'p1',
    shortId: 'P000001',
    fullName: 'Uwase Marie',
    village: 'Nyamata',
    consentAt: now,
    createdAt: now,
    updatedAt: now,
    syncState: SyncState.queued,
  );

  Visit visit({
    bool urgent = false,
    String condition = 'Stable',
    DateTime? followUpOn,
    DateTime? at,
  }) => Visit(
    id: 'v${at?.millisecondsSinceEpoch ?? 0}',
    shortCode: 'abcdef12',
    patientId: 'p1',
    type: VisitType.maternal,
    answersJson: '{"general_condition":"$condition"}',
    isUrgent: urgent,
    followUpOn: followUpOn,
    recordedAt: at ?? now,
    syncState: SyncState.queued,
  );

  StatusKind status(List<Visit> visits) => PatientView(patient, visits).status;

  test('no visits, or a plain visit, is stable', () {
    expect(status([]), StatusKind.stable);
    expect(status([visit()]), StatusKind.stable);
  });

  test('a visit tagged "Needs attention" flags the patient', () {
    expect(status([visit(condition: needsAttention)]), StatusKind.attention);
  });

  test(
    'danger signs win over "Needs attention", which wins over a due follow-up',
    () {
      final due = now.subtract(const Duration(days: 1));
      expect(
        status([visit(urgent: true, condition: needsAttention)]),
        StatusKind.urgent,
      );
      expect(
        status([visit(condition: needsAttention, followUpOn: due)]),
        StatusKind.attention,
      );
      expect(status([visit(followUpOn: due)]), StatusKind.followUp);
    },
  );

  test('only the latest visit counts', () {
    final older = visit(
      urgent: true,
      at: now.subtract(const Duration(days: 3)),
    );
    expect(status([older, visit(at: now)]), StatusKind.stable);
  });
}

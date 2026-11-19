import 'dart:convert';

import '../core/widgets/widgets.dart';
import '../data/db.dart';
import '../data/models.dart';

String visitTypeLabel(VisitType t) => switch (t) {
  VisitType.maternal => 'Maternal Health',
  VisitType.child => 'Child Health',
  VisitType.malaria => 'Malaria',
  VisitType.nutrition => 'Malnutrition',
};

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String two(int n) => n.toString().padLeft(2, '0');
String dayMonth(DateTime d) => '${d.day} ${months[d.month - 1]}';
String fullDate(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String relativeDay(DateTime d, [DateTime? now]) {
  final today = now ?? DateTime.now();
  if (sameDay(d, today)) return 'Today';
  if (sameDay(d, today.subtract(const Duration(days: 1)))) return 'Yesterday';
  return dayMonth(d);
}

/// The visit form's "General condition" tag that flags a patient, stored as `answers.general_condition`.
const needsAttention = 'Needs attention';

/// A patient with what the list and profile screens derive from their visits.
class PatientView {
  PatientView(this.patient, List<Visit> visits)
    : visits = ([...visits]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)));

  final Patient patient;
  final List<Visit> visits; // newest first

  Visit? get latest => visits.isEmpty ? null : visits.first;

  /// From the latest visit: danger signs, then the CHW's "Needs attention" tag, then a due follow-up.
  StatusKind get status {
    final v = latest;
    if (v == null) return StatusKind.stable;
    if (v.isUrgent) return StatusKind.urgent;
    final answers = jsonDecode(v.answersJson);
    if (answers is Map && answers['general_condition'] == needsAttention) {
      return StatusKind.attention;
    }
    final due = v.followUpOn;
    if (due != null && !due.isAfter(DateTime.now())) return StatusKind.followUp;
    return StatusKind.stable;
  }

  String get ageSex {
    final p = patient;
    final age = p.birthDate != null
        ? DateTime.now().difference(p.birthDate!).inDays ~/ 365
        : p.ageEstimate;
    final sex = switch (p.sex) {
      'F' => 'Female',
      'M' => 'Male',
      _ => null,
    };
    return [if (age != null) '$age years', ?sex].join(' \u00B7 ');
  }

  String get when =>
      latest == null ? 'No visits' : relativeDay(latest!.recordedAt.toLocal());
}

List<PatientView> buildPatientViews(
  List<Patient> patients,
  List<Visit> visits,
) => [
  for (final p in patients)
    PatientView(p, visits.where((v) => v.patientId == p.id).toList()),
];

class SyncCounts {
  const SyncCounts({
    required this.synced,
    required this.pending,
    required this.failed,
  });
  final int synced;
  final int pending;
  final int failed;
}

SyncCounts syncCounts(List<Patient> patients, List<Visit> visits) {
  final states = [
    ...patients.map((p) => p.syncState),
    ...visits.map((v) => v.syncState),
  ];
  return SyncCounts(
    synced: states.where((s) => s == SyncState.synced).length,
    pending: states
        .where((s) => s == SyncState.local || s == SyncState.queued)
        .length,
    failed: states.where((s) => s == SyncState.failed).length,
  );
}

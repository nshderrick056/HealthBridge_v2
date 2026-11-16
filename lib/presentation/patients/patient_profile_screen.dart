import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db.dart';
import '../../data/providers.dart';
import '../record/record_visit_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';
import 'patient_profile_controller.dart';
import 'register_patient_screen.dart';

class PatientProfileScreen extends ConsumerWidget {
  const PatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  /// Asks first, then archives, leaves the profile and offers Undo.
  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this patient?'),
        content: Text(
          '${patient.fullName} will be hidden from your lists. '
          'Their visits are kept, and you can undo this straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(patientActionsProvider);
    try {
      final archived = await actions.archive(patient);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${patient.fullName} archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.restore(archived),
          ),
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not archive. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final showAll = ref.watch(historyExpandedProvider(patientId));
    void toggleHistory() =>
        ref.read(historyExpandedProvider(patientId).notifier).toggle();
    final found = patients.where((p) => p.id == patientId);
    if (found.isEmpty) return const Scaffold(body: SizedBox.shrink());
    final view = PatientView(
      found.first,
      visits.where((v) => v.patientId == patientId).toList(),
    );
    final latest = view.latest;
    final shown = view.visits.take(showAll ? 50 : 3).toList();
    final due = latest?.followUpOn;
    final first = view.patient.fullName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: PageBody(
        children: [
          Row(
            children: [
              HbCircleButton(
                icon: Icons.chevron_left,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              HbCircleButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit patient',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RegisterPatientScreen(patient: view.patient),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              HbCircleButton(
                icon: Icons.archive_outlined,
                tooltip: 'Archive patient',
                onPressed: () => _archive(context, ref, view.patient),
              ),
            ],
          ),
          HbGradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HbAvatar(
                      view.patient.fullName,
                      kind: AvatarKind.lime,
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            view.patient.fullName,
                            style: HbText.headingLarge.copyWith(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            [
                              if (view.ageSex.isNotEmpty) view.ageSex,
                              view.patient.village,
                            ].join(' · '),
                            style: HbText.bodySmall.copyWith(
                              color: HbColors.onBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x33FFFFFF)),
                const SizedBox(height: 12),
                Text(
                  switch (view.status) {
                    StatusKind.urgent => 'Urgent at the last visit',
                    StatusKind.attention => 'Needs attention',
                    _ when due != null => 'Follow-up due ${fullDate(due)}',
                    _ => 'Last visit: ${view.when}',
                  },
                  style: HbText.headingSmall.copyWith(
                    color: view.status == StatusKind.urgent
                        ? Colors.white
                        : HbColors.lime,
                  ),
                ),
                Text(
                  latest == null
                      ? 'No visits yet · ID ${view.patient.shortId}'
                      : '${visitTypeLabel(latest.type)} · ID ${view.patient.shortId}',
                  style: HbText.bodySmall.copyWith(color: HbColors.onBrand),
                ),
              ],
            ),
          ),
          HbButton.primary(
            'Record visit for $first',
            icon: Icons.add,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecordVisitScreen(patientId: patientId),
              ),
            ),
          ),
          if (shown.isNotEmpty) ...[
            SectionHeading(
              'Visits',
              action: view.visits.length > 3
                  ? (showAll ? 'Show less' : 'View all')
                  : null,
              onAction: toggleHistory,
            ),
            HbCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, v) in shown.indexed) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: HbDivider(),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${fullDate(v.recordedAt.toLocal())} · ${visitTypeLabel(v.type)}',
                                  style: HbText.headingSmall,
                                ),
                              ),
                              if (v.isUrgent)
                                Text(
                                  'Urgent',
                                  style: HbText.labelMedium.copyWith(
                                    color: HbColors.red,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            v.notes?.isNotEmpty == true
                                ? v.notes!
                                : 'No notes recorded.',
                            style: HbText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: const SubPageNav(current: 1),
    );
  }
}

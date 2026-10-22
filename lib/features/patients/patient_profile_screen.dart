import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../record/record_visit_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final found = patients.where((p) => p.id == widget.patientId);
    if (found.isEmpty) return const Scaffold(body: SizedBox.shrink());
    final view = PatientView(
      found.first,
      visits.where((v) => v.patientId == widget.patientId).toList(),
    );
    final latest = view.latest;
    final previous = view.visits.skip(1).take(_showAll ? 50 : 2).toList();
    final due = latest?.followUpOn;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      body: PageBody(
        children: [
          const PageHeader(
            title: 'Patient profile',
            subtitle: 'Care details and visit history',
          ),
          Column(
            children: [
              HbCard(
                shadow: true,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.patient.fullName,
                                style: HbText.headingMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(view.ageSex, style: HbText.bodySmall),
                            ],
                          ),
                        ),
                        StatusChip(
                          view.status == StatusKind.followUp
                              ? StatusKind.stable
                              : view.status,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: HbColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(view.patient.village, style: HbText.bodySmall),
                          ],
                        ),
                        Text(view.when, style: HbText.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Patient ID \u00B7 ${view.patient.shortId}',
                    style: HbText.bodySmall,
                  ),
                  if (view.status == StatusKind.followUp)
                    const StatusChip(StatusKind.followUp),
                ],
              ),
            ],
          ),
          if (latest != null)
            HbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent visit', style: HbText.labelMedium),
                  const SizedBox(height: 8),
                  DetailRow('Date', fullDate(latest.recordedAt.toLocal())),
                  const SizedBox(height: 8),
                  DetailRow('Visit type', visitTypeLabel(latest.type)),
                  const SizedBox(height: 8),
                  Text(
                    latest.notes?.isNotEmpty == true
                        ? latest.notes!
                        : 'No notes recorded.',
                    style: HbText.bodySmall,
                  ),
                ],
              ),
            ),
          if (previous.isNotEmpty)
            HbCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SectionHeading(
                    'Previous visits',
                    action: _showAll ? 'Show less' : 'View all',
                    onAction: () => setState(() => _showAll = !_showAll),
                  ),
                  for (final v in previous) ...[
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fullDate(v.recordedAt.toLocal()),
                          style: HbText.bodySmall,
                        ),
                        Text(visitTypeLabel(v.type), style: HbText.labelSmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (due != null)
            HbCard(
              color: HbColors.amberTint,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming follow-up', style: HbText.labelMedium),
                  const SizedBox(height: 5),
                  Text(fullDate(due), style: HbText.headingSmall),
                  const SizedBox(height: 5),
                  Text(
                    '${visitTypeLabel(latest!.type)} check-in',
                    style: HbText.bodySmall.copyWith(color: HbColors.warning),
                  ),
                ],
              ),
            ),
          Column(
            children: [
              HbButton.primary(
                'Record new visit',
                icon: Icons.add_circle_outline,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RecordVisitScreen(patientId: widget.patientId),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              HbButton.secondary(
                _showAll ? 'Show recent only' : 'View history',
                onPressed: () => setState(() => _showAll = !_showAll),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const SubPageNav(current: 1),
    );
  }
}

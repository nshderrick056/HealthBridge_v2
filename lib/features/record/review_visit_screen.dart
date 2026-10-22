import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';
import 'urgent_detected_screen.dart';
import 'record_saved_screen.dart';
import 'visit_form.dart';

class ReviewVisitScreen extends ConsumerStatefulWidget {
  const ReviewVisitScreen({
    super.key,
    required this.form,
    required this.draftKey,
  });

  final VisitForm form;
  final String draftKey;

  @override
  ConsumerState<ReviewVisitScreen> createState() => _ReviewVisitScreenState();
}

class _ReviewVisitScreenState extends ConsumerState<ReviewVisitScreen> {
  var _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final f = widget.form;
    final visit = await ref
        .read(visitsRepositoryProvider)
        .record(
          patientId: f.patient.id,
          type: f.type,
          answers: f.answers,
          signCodes: f.signs.toList(),
          notes: f.notes.trim().isEmpty ? null : f.notes.trim(),
        );
    await ref.read(draftsRepositoryProvider).delete(widget.draftKey);
    if (!mounted) return;
    final next = visit.isUrgent
        ? UrgentDetectedScreen(visitId: visit.id)
        : RecordSavedScreen(visitId: visit.id);
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    final online = ref.watch(isOnlineProvider);
    final labels =
        ref.watch(dangerSignLabelsProvider).value ?? const <String, String>{};
    final symptoms = f.symptoms
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final view = PatientView(f.patient, const []);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      bottomNavigationBar: const SubPageNav(current: 2),
      body: PageBody(
        children: [
          const PageHeader(
            title: 'Review visit',
            subtitle: 'Check details before submitting',
          ),
          HbCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient details', style: HbText.labelMedium),
                const SizedBox(height: 7),
                Text(f.patient.fullName, style: HbText.headingSmall),
                const SizedBox(height: 7),
                Text(
                  [
                    if (view.ageSex.isNotEmpty) view.ageSex,
                    f.patient.village,
                    f.patient.shortId,
                  ].join(' \u00B7 '),
                  style: HbText.bodySmall,
                ),
              ],
            ),
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visit summary', style: HbText.labelMedium),
                const SizedBox(height: 8),
                DetailRow('Visit type', visitTypeLabel(f.type)),
                const SizedBox(height: 8),
                DetailRow('Visit date', fullDate(DateTime.now())),
                const SizedBox(height: 8),
                const HbDivider(),
                if (symptoms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Symptoms / observations',
                    style: HbText.labelSmall.copyWith(
                      color: HbColors.textSecondary,
                    ),
                  ),
                  for (final s in symptoms) BulletLine(s, HbColors.tealTint),
                ],
                if (f.signs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Danger signs',
                    style: HbText.labelSmall.copyWith(color: HbColors.red),
                  ),
                  for (final c in f.signs)
                    BulletLine(labels[c] ?? c, HbColors.red),
                ],
                const SizedBox(height: 8),
                Text(
                  'Key assessment',
                  style: HbText.labelSmall.copyWith(
                    color: HbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                if (f.temperature != null) ...[
                  DetailRow('Temperature', '${f.temperature} \u00B0C'),
                  const SizedBox(height: 5),
                ],
                DetailRow('General condition', f.condition),
                if (f.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes',
                    style: HbText.labelSmall.copyWith(
                      color: HbColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.notes.trim(),
                    style: HbText.bodySmall.copyWith(
                      color: HbColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connectivity status', style: HbText.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      online
                          ? 'Ready to submit now'
                          : 'Will be saved and synced later',
                      style: HbText.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(online ? StatusKind.online : StatusKind.offline),
            ],
          ),
          Column(
            children: [
              HbButton.primary(
                _busy ? 'Saving...' : 'Submit visit',
                icon: Icons.add_circle_outline,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 8),
              HbButton.secondary(
                'Edit',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

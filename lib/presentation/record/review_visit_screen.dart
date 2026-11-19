import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';
import 'review_visit_controller.dart';
import 'urgent_detected_screen.dart';
import 'record_saved_screen.dart';
import 'visit_form.dart';

class ReviewVisitScreen extends ConsumerWidget {
  const ReviewVisitScreen({
    super.key,
    required this.form,
    required this.draftKey,
  });

  final VisitForm form;
  final String draftKey;

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final visit = await ref
          .read(submitVisitProvider.notifier)
          .submit(form, draftKey);
      final next = visit.isUrgent
          ? UrgentDetectedScreen(visitId: visit.id)
          : RecordSavedScreen(visitId: visit.id);
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => next),
        (r) => r.isFirst,
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the visit. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = form;
    final busy = ref.watch(submitVisitProvider);
    final online = ref.watch(isOnlineProvider);
    final labels =
        ref.watch(dangerSignLabelsProvider).value ?? const <String, String>{};
    final symptoms = f.symptoms
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final urgent = f.signs.isNotEmpty;
    final now = DateTime.now();
    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 2),
      body: PageBody(
        children: [
          const HbStepBar(step: 'Step 3 / 3'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check and save', style: HbText.headingLarge),
              const SizedBox(height: 4),
              Text(
                '${f.patient.fullName} · today ${clock(now)}',
                style: HbText.bodySmall,
              ),
            ],
          ),
          if (urgent)
            HbCard(
              color: HbColors.red,
              shadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This visit is urgent',
                    style: HbText.headingSmall.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'After saving, you send the alert to the health centre.',
                    style: HbText.bodySmall.copyWith(color: HbColors.onRed),
                  ),
                ],
              ),
            ),
          const SectionHeading('Visit'),
          HbCard(
            child: Column(
              children: [
                DetailRow('Type', visitTypeLabel(f.type)),
                if (urgent) ...[
                  const SizedBox(height: 12),
                  DetailRow(
                    'Danger signs',
                    [for (final c in f.signs) labels[c] ?? c].join(', '),
                    valueColor: HbColors.red,
                  ),
                ],
                if (f.temperature != null) ...[
                  const SizedBox(height: 12),
                  DetailRow('Temperature', '${f.temperature} °C'),
                ],
                const SizedBox(height: 12),
                DetailRow('General condition', f.condition),
              ],
            ),
          ),
          if (symptoms.isNotEmpty) ...[
            const SectionHeading('Symptoms / observations'),
            HbCard(
              child: Column(
                children: [
                  for (final s in symptoms) BulletLine(s, HbColors.brand),
                ],
              ),
            ),
          ],
          if (f.notes.trim().isNotEmpty) ...[
            const SectionHeading('Notes'),
            HbCard(child: Text(f.notes.trim(), style: HbText.bodyMedium)),
          ],
          HbPill(
            online
                ? 'Online · it sends now'
                : urgent
                ? 'Offline · the alert can go by SMS'
                : 'Offline · saved on this phone, sent later',
            dot: online ? HbColors.brand : HbColors.amberMark,
          ),
          HbButton.primary(
            busy ? 'Saving...' : 'Save visit',
            onPressed: busy ? null : () => _submit(context, ref),
          ),
          HbButton.secondary(
            'Edit',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

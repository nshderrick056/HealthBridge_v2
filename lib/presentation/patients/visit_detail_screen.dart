import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';

/// Everything recorded at one of the patient's visits, from this phone's own records.
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId)).value;
    final labels =
        ref.watch(dangerSignLabelsProvider).value ?? const <String, String>{};
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final v = detail.visit;
    final answers = (jsonDecode(v.answersJson) as Map?) ?? const {};
    final temperature = answers['temperature'];
    final condition = answers['general_condition'] as String?;
    final symptoms = (answers['symptoms'] as String?)?.trim() ?? '';
    final at = v.recordedAt.toLocal();
    final sent = switch (v.syncState) {
      SyncState.synced => 'Sent to the server',
      SyncState.failed => 'Could not be sent; retry from Sync',
      _ => 'Waiting to send',
    };

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 1),
      body: PageBody(
        children: [
          const HbStepBar(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(visitTypeLabel(v.type), style: HbText.headingLarge),
              const SizedBox(height: 4),
              Text(
                '${detail.patient.fullName} · ${fullDate(at)} ${clock(at)}',
                style: HbText.bodySmall,
              ),
            ],
          ),
          if (v.isUrgent)
            HbCard(
              color: HbColors.red,
              shadow: false,
              child: Text(
                'This visit was urgent',
                style: HbText.headingSmall.copyWith(color: Colors.white),
              ),
            ),
          if (detail.signs.isNotEmpty) ...[
            const SectionHeading('Danger signs'),
            HbCard(
              child: Column(
                children: [
                  for (final c in detail.signs)
                    BulletLine(labels[c] ?? c, HbColors.red),
                ],
              ),
            ),
          ],
          const SectionHeading('What was recorded'),
          HbCard(
            child: Column(
              children: [
                DetailRow('Visit type', visitTypeLabel(v.type)),
                if (temperature != null) ...[
                  const SizedBox(height: 12),
                  DetailRow('Temperature', '$temperature °C'),
                ],
                if (condition != null) ...[
                  const SizedBox(height: 12),
                  DetailRow('General condition', condition),
                ],
                if (v.followUpOn != null) ...[
                  const SizedBox(height: 12),
                  DetailRow('Follow-up', fullDate(v.followUpOn!.toLocal())),
                ],
                const SizedBox(height: 12),
                DetailRow(
                  'Sync',
                  sent,
                  valueColor: v.syncState == SyncState.synced
                      ? HbColors.brand
                      : HbColors.warning,
                ),
              ],
            ),
          ),
          if (symptoms.isNotEmpty) ...[
            const SectionHeading('Symptoms / observations'),
            HbCard(child: Text(symptoms, style: HbText.bodyMedium)),
          ],
          if (v.notes?.trim().isNotEmpty == true) ...[
            const SectionHeading('Notes'),
            HbCard(child: Text(v.notes!.trim(), style: HbText.bodyMedium)),
          ],
        ],
      ),
    );
  }
}

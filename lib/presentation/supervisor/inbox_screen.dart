import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/supervision.dart';
import '../patients/patients_screen.dart';
import '../view_models.dart';
import 'case_screen.dart';
import 'supervisor_controllers.dart';

/// The supervisor's urgent-alert inbox for their health centre (Figma supervisor frame 1).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  static const _filters = [
    ('open', 'Open'),
    ('new', 'New'),
    ('escalated', 'Escalated'),
    ('follow_up', 'Follow-up'),
    ('resolved', 'Resolved'),
    (null, 'All'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final alerts = ref.watch(inboxProvider);
    return PageBody(
      children: [
        const PageHeader(
          title: 'Urgent alerts',
          subtitle: 'Your health centre, updated every 10 seconds',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in _filters)
              ChoiceChipPill(
                label: label,
                selected: filter == value,
                onTap: () => ref.read(inboxFilterProvider.notifier).show(value),
              ),
          ],
        ),
        ...alerts.when(
          data: (list) => list.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No alerts here.', style: HbText.bodySmall),
                    ),
                  ),
                ]
              : [for (final a in list) AlertCard(alert: a)],
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            Text(
              'Could not load alerts. Check your connection.',
              style: HbText.bodySmall.copyWith(color: HbColors.red),
            ),
          ],
        ),
      ],
    );
  }
}

/// One case in the inbox.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final AlertSummary alert;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final when = a.createdAt == null
        ? ''
        : '${relativeDay(a.createdAt!)} ${clock(a.createdAt!)}';
    return HbCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CaseScreen(alertId: a.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.patientName ?? 'Patient ${a.patientShortId ?? ''}',
                  style: HbText.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(a.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (a.chwName != null) 'CHW ${a.chwName}',
              if (a.village != null && a.village!.isNotEmpty) a.village!,
              when,
            ].join(' · '),
            style: HbText.bodySmall,
          ),
          if (a.dangerSigns.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              a.dangerSigns.join(', '),
              style: HbText.bodySmall.copyWith(color: HbColors.red),
            ),
          ],
          if (a.channel == 'sms' || a.isPartial) ...[
            const SizedBox(height: 6),
            Text(
              a.isPartial
                  ? 'By SMS · full record not received yet'
                  : 'Arrived by SMS',
              style: HbText.caption.copyWith(color: HbColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

/// A case's status as a small coloured label.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      AlertStatus.newCase => (HbColors.red, HbColors.redTint),
      AlertStatus.escalated => (HbColors.red, HbColors.redTint),
      AlertStatus.followUp => (HbColors.warning, HbColors.amberTint),
      AlertStatus.reviewed => (HbColors.teal, HbColors.tealTint),
      AlertStatus.resolved => (HbColors.green, HbColors.greenTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: HbText.labelSmall.copyWith(color: fg)),
    );
  }
}

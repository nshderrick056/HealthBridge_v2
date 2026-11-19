import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../domain/entities/supervision.dart';
import '../patients/patients_screen.dart';
import '../view_models.dart';
import 'case_screen.dart';
import 'supervisor_controllers.dart';

/// The supervisor's urgent-alert inbox for their health centre (Figma v3 "Supervisor alerts").
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
    final session = ref.watch(sessionProvider);
    return PageBody(
      children: [
        if (session != null)
          ProfileHeader(name: session.fullName, role: 'Supervisor'),
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
                  HbCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No alerts here', style: HbText.headingMedium),
                        const SizedBox(height: 6),
                        Text(
                          'A new alert shows here as soon as a CHW sends one, '
                          'by internet or by SMS.',
                          style: HbText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  HbCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, a) in list.indexed) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: HbDivider(),
                            ),
                          AlertCard(alert: a),
                        ],
                      ],
                    ),
                  ),
                ],
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            Text(
              'Could not load alerts. Check your connection.',
              style: HbText.bodyMedium.copyWith(color: HbColors.red),
            ),
          ],
        ),
      ],
    );
  }
}

/// One case in the inbox: an avatar coloured by status, who and what, and the status in words.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final AlertSummary alert;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final name = a.patientName ?? 'Patient ${a.patientShortId ?? ''}';
    final when = a.createdAt == null
        ? ''
        : '${relativeDay(a.createdAt!)} ${clock(a.createdAt!)}';
    final (_, color) = StatusTag.colours(a.status);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CaseScreen(alertId: a.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HbAvatar(
              name,
              kind: switch (a.status) {
                AlertStatus.newCase ||
                AlertStatus.escalated => AvatarKind.urgent,
                AlertStatus.followUp => AvatarKind.due,
                _ => AvatarKind.plain,
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HbText.headingSmall),
                  Text(
                    [
                      if (a.chwName != null) 'CHW ${a.chwName}',
                      if (a.village != null && a.village!.isNotEmpty)
                        a.village!,
                      when,
                    ].join(' · '),
                    style: HbText.bodySmall,
                  ),
                  if (a.dangerSigns.isNotEmpty)
                    Text(
                      a.dangerSigns.join(', '),
                      style: HbText.bodySmall.copyWith(color: HbColors.red),
                    ),
                  if (a.channel == 'sms' || a.isPartial)
                    Text(
                      a.isPartial
                          ? 'By SMS · full record not received yet'
                          : 'Arrived by SMS',
                      style: HbText.bodySmall.copyWith(color: HbColors.warning),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              a.status.label,
              style: HbText.labelMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A case's status as a tinted pill.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  final AlertStatus status;

  /// (background, text) for a status: red while it needs action, amber for follow-up.
  static (Color, Color) colours(AlertStatus status) => switch (status) {
    AlertStatus.newCase => (HbColors.redTint, HbColors.red),
    AlertStatus.escalated => (HbColors.redTint, HbColors.red),
    AlertStatus.followUp => (HbColors.amberTint, HbColors.warning),
    AlertStatus.reviewed => (HbColors.tealTint, HbColors.brand),
    AlertStatus.resolved => (HbColors.greenTint, HbColors.brand),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colours(status);
    return HbPill(status.label, background: bg, foreground: fg);
  }
}

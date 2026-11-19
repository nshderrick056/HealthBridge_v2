import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../record/sms_alert_sent_screen.dart';
import '../view_models.dart';

/// Urgent alerts this CHW has raised and where each one stands. Not in Figma; built from its components.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final dispatches = ref.watch(allDispatchesProvider).value ?? const [];
    final urgent = visits.where((v) => v.isUrgent).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return PageBody(
      children: [
        PageHeader(
          title: 'Alerts',
          subtitle:
              '${urgent.length} urgent ${urgent.length == 1 ? 'case' : 'cases'}',
        ),
        if (urgent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No urgent cases.')),
          ),
        for (final v in urgent)
          Builder(
            builder: (_) {
              final p = patients.where((p) => p.id == v.patientId).firstOrNull;
              final state = dispatches
                  .where((d) => d.visitId == v.id)
                  .firstOrNull
                  ?.state;
              return PatientCard(
                name: p?.fullName ?? 'Unknown patient',
                detail: visitTypeLabel(v.type),
                status: switch (state) {
                  DispatchState.sentSms ||
                  DispatchState.confirmed => StatusKind.smsSent,
                  _ => StatusKind.urgent,
                },
                village: p?.village ?? '',
                when: relativeDay(v.recordedAt.toLocal()),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SmsAlertSentScreen(visitId: v.id),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

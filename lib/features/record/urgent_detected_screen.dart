import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../urgent/urgent_service.dart';
import '../patients/patient_profile_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';
import 'sms_alert_sent_screen.dart';

class UrgentDetectedScreen extends ConsumerWidget {
  const UrgentDetectedScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId)).value;
    final labels =
        ref.watch(dangerSignLabelsProvider).value ?? const <String, String>{};
    final online = ref.watch(isOnlineProvider);
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final view = PatientView(detail.patient, const []);

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: null),
      body: PageBody(
        children: [
          const PageHeader(
            title: 'Urgent case detected',
            subtitle: 'Immediate attention required',
          ),
          const NoticeCard(
            color: HbColors.red,
            tint: HbColors.redTint,
            glyph: '!',
            title: 'This case requires immediate attention',
            body: 'Review the warning indicators and send an alert now.',
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Case summary', style: HbText.labelMedium),
                const SizedBox(height: 8),
                Text(detail.patient.fullName, style: HbText.headingLarge),
                const SizedBox(height: 8),
                Text(
                  [
                    if (view.ageSex.isNotEmpty) view.ageSex,
                    detail.patient.village,
                    detail.patient.shortId,
                  ].join(' \u00B7 '),
                  style: HbText.bodySmall,
                ),
                const SizedBox(height: 8),
                DetailRow(
                  'Urgent case type',
                  '${visitTypeLabel(detail.visit.type)} warning signs',
                ),
              ],
            ),
          ),
          HbCard(
            color: HbColors.redTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key warning indicators', style: HbText.labelMedium),
                const SizedBox(height: 8),
                for (final c in detail.signs)
                  BulletLine(labels[c] ?? c, HbColors.red),
              ],
            ),
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Connectivity status', style: HbText.labelMedium),
                    StatusChip(online ? StatusKind.online : StatusKind.offline),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'HealthBridge will attempt to send the alert immediately. If internet is unavailable, SMS fallback will be used.',
                  style: HbText.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            children: [
              HbButton.primary(
                'Send urgent alert',
                icon: Icons.add_circle_outline,
                // Internet first, SMS fallback (lib/urgent/); the next screen follows its progress.
                onPressed: () {
                  unawaited(ref.read(urgentDispatcherProvider).send(visitId));
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => SmsAlertSentScreen(visitId: visitId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              HbButton.secondary(
                'Review details',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PatientProfileScreen(patientId: detail.patient.id),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

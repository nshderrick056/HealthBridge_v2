import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../patients/patient_profile_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';

/// Shows the urgent alert's real state. Until the senders from slice 6 move it on, it stays on "sending".
class SmsAlertSentScreen extends ConsumerWidget {
  const SmsAlertSentScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId)).value;
    final state =
        ref
            .watch(allDispatchesProvider)
            .value
            ?.where((d) => d.visitId == visitId)
            .firstOrNull
            ?.state ??
        DispatchState.sending;
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final view = PatientView(detail.patient, const []);
    final sent =
        state == DispatchState.sentSms || state == DispatchState.confirmed;
    final unconfirmed = state == DispatchState.unconfirmed;

    final (title, body, subtitle) = switch (state) {
      DispatchState.sending => (
        'Sending urgent alert',
        'The alert is queued and will go out as soon as possible.',
        'Escalation in progress',
      ),
      DispatchState.sentSms => (
        'Urgent alert sent successfully',
        'The health centre has been notified by SMS.',
        'Immediate escalation completed',
      ),
      DispatchState.confirmed => (
        'Alert received by the health centre',
        'The health centre confirmed it received the alert.',
        'Immediate escalation completed',
      ),
      DispatchState.unconfirmed => (
        'No confirmation yet',
        'Call the health centre to make sure they received the alert.',
        'Escalation not confirmed',
      ),
    };

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 3),
      body: PageBody(
        children: [
          PageHeader(title: 'SMS alert sent', subtitle: subtitle),
          NoticeCard(
            color: unconfirmed ? HbColors.warning : HbColors.red,
            tint: unconfirmed ? HbColors.amberTint : HbColors.redTint,
            glyph: sent ? '\u2713' : (unconfirmed ? '?' : '\u2026'),
            title: title,
            body: body,
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Urgent case', style: HbText.labelMedium),
                    StatusChip(
                      sent ? StatusKind.smsSent : StatusKind.pending,
                      label: sent
                          ? null
                          : (unconfirmed ? 'Unconfirmed' : 'Sending'),
                    ),
                  ],
                ),
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
                const HbDivider(),
                const SizedBox(height: 8),
                DetailRow(
                  'Urgent case type',
                  '${visitTypeLabel(detail.visit.type)} warning signs',
                  valueColor: HbColors.red,
                ),
                const SizedBox(height: 8),
                DetailRow(
                  'Alert status',
                  sent
                      ? 'SMS sent'
                      : (unconfirmed ? 'Not confirmed' : 'Sending'),
                  valueColor: sent ? HbColors.green : HbColors.warning,
                ),
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
                    Text('Full patient record', style: HbText.labelMedium),
                    const StatusChip(
                      StatusKind.pending,
                      label: 'Waiting for internet sync',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'The complete patient record will sync automatically when internet returns.',
                  style: HbText.bodySmall,
                ),
              ],
            ),
          ),
          HbCard(
            color: HbColors.redTint,
            padding: const EdgeInsets.all(12),
            child: const Column(
              children: [
                BulletLine(
                  'Essential urgent information is sent by SMS.',
                  HbColors.red,
                ),
                BulletLine(
                  'The complete record remains safely stored on this device.',
                  HbColors.red,
                ),
              ],
            ),
          ),
          Column(
            children: [
              HbButton.primary(
                'Back to home',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  ref.read(tabIndexProvider.notifier).state = 0;
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              const SizedBox(height: 8),
              HbButton.secondary(
                'View case',
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

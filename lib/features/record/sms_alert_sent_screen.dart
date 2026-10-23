import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../urgent/urgent_service.dart';
import '../patients/patient_profile_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';

/// Follows the urgent alert's real state (lib/urgent/): internet first, then SMS and its ack. With no
/// ack after 10 minutes it offers Resend and a call; the store build, which cannot read SMS, also
/// lets the CHW confirm by hand once the "HB OK" reply is in the inbox.
class SmsAlertSentScreen extends ConsumerWidget {
  const SmsAlertSentScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId)).value;
    final dispatch = ref
        .watch(allDispatchesProvider)
        .value
        ?.where((d) => d.visitId == visitId)
        .firstOrNull;
    final state = dispatch?.state ?? DispatchState.sending;
    final internet = (dispatch?.channel ?? 'internet') == 'internet';
    final readsAcks = ref.watch(urgentSenderProvider).readsAcks;
    final callNumber = ref.watch(callNumberProvider).value;
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final view = PatientView(detail.patient, const []);
    final sent =
        state == DispatchState.sentSms || state == DispatchState.confirmed;
    final unconfirmed = state == DispatchState.unconfirmed;

    final (title, body, subtitle) = switch (state) {
      DispatchState.sending when internet => (
        'Sending urgent alert',
        'Trying the internet first. SMS is used if it does not get through.',
        'Escalation in progress',
      ),
      DispatchState.sending => (
        'Sending urgent alert by SMS',
        'The internet did not get through, so the alert is going by SMS.',
        'Escalation in progress',
      ),
      DispatchState.sentSms when readsAcks => (
        'Sent by SMS, waiting for confirmation',
        'The health centre replies by SMS. This can take up to 10 minutes.',
        'Escalation in progress',
      ),
      DispatchState.sentSms => (
        'Sent by SMS, waiting for confirmation',
        'Tap Send in your messages app. When the "HB OK" reply arrives, tap "I got the confirmation".',
        'Escalation in progress',
      ),
      DispatchState.confirmed when internet => (
        'Alert received by the health centre',
        'The alert reached the health centre over the internet.',
        'Immediate escalation completed',
      ),
      DispatchState.confirmed => (
        'Alert received by the health centre',
        'The health centre confirmed it received the alert.',
        'Immediate escalation completed',
      ),
      DispatchState.unconfirmed => (
        'No confirmation yet',
        'Resend the SMS, or call the health centre to make sure they received the alert.',
        'Escalation not confirmed',
      ),
    };

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 3),
      body: PageBody(
        children: [
          PageHeader(
            title: internet ? 'Urgent alert sent' : 'SMS alert sent',
            subtitle: subtitle,
          ),
          NoticeCard(
            color: unconfirmed ? HbColors.warning : HbColors.red,
            tint: unconfirmed ? HbColors.amberTint : HbColors.redTint,
            glyph: sent ? '✓' : (unconfirmed ? '?' : '…'),
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
                    Flexible(
                      child: Text('Urgent case', style: HbText.labelMedium),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      sent ? StatusKind.smsSent : StatusKind.pending,
                      label: sent
                          ? (internet ? 'Sent' : null)
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
                  ].join(' · '),
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
                  switch (state) {
                    DispatchState.confirmed => 'Confirmed',
                    DispatchState.sentSms => 'SMS sent',
                    DispatchState.unconfirmed => 'Not confirmed',
                    DispatchState.sending => 'Sending',
                  },
                  valueColor: sent ? HbColors.green : HbColors.warning,
                ),
              ],
            ),
          ),
          if (!internet) ...[
            HbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Full patient record',
                          style: HbText.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
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
          ],
          Column(
            children: [
              if (unconfirmed) ...[
                HbButton.primary(
                  'Resend SMS',
                  icon: Icons.refresh,
                  onPressed: () => unawaited(
                    ref.read(urgentDispatcherProvider).sendSms(visitId),
                  ),
                ),
                const SizedBox(height: 8),
                HbButton.secondary(
                  'Call health centre',
                  icon: Icons.call_outlined,
                  onPressed: () => unawaited(
                    launchUrl(Uri(scheme: 'tel', path: callNumber ?? '')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (!readsAcks &&
                  (state == DispatchState.sentSms || unconfirmed)) ...[
                HbButton.secondary(
                  'I got the confirmation',
                  icon: Icons.check_circle_outline,
                  onPressed: () => unawaited(
                    ref.read(urgentDispatcherProvider).confirm(visitId),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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

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

    final (title, body) = switch (state) {
      DispatchState.sending when internet => (
        'Sending urgent alert',
        'Trying the internet first. SMS is used if it does not get through.',
      ),
      DispatchState.sending => (
        'Sending urgent alert by SMS',
        'The internet did not get through, so the alert is going by SMS.',
      ),
      DispatchState.sentSms when readsAcks => (
        'Sent by SMS, waiting for confirmation',
        'The health centre replies by SMS. This can take up to 10 minutes.',
      ),
      DispatchState.sentSms => (
        'Sent by SMS, waiting for confirmation',
        'Tap Send in your messages app. When the "HB OK" reply arrives, tap "I got the confirmation".',
      ),
      DispatchState.confirmed when internet => (
        'Alert received by the health centre',
        'The alert reached the health centre over the internet.',
      ),
      DispatchState.confirmed => (
        'Alert received by the health centre',
        'The health centre confirmed it received the alert.',
      ),
      DispatchState.unconfirmed => (
        'No confirmation yet',
        'Resend the SMS, or call the health centre to make sure they received the alert.',
      ),
    };
    // Green once the health centre has it, amber when unconfirmed, red while it is on its way.
    final (bg, fg, sub) = switch (state) {
      DispatchState.confirmed => (
        HbColors.brand,
        Colors.white,
        HbColors.onBrand,
      ),
      DispatchState.unconfirmed => (
        HbColors.amberTint,
        HbColors.warning,
        HbColors.ink,
      ),
      _ => (HbColors.red, Colors.white, HbColors.onRed),
    };

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 3),
      body: PageBody(
        children: [
          Text(
            internet ? 'Urgent alert sent' : 'SMS alert sent',
            style: HbText.headingLarge,
          ),
          HbCard(
            color: bg,
            shadow: false,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HbText.headingMedium.copyWith(color: fg)),
                const SizedBox(height: 6),
                Text(body, style: HbText.bodyMedium.copyWith(color: sub)),
              ],
            ),
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HbAvatar(detail.patient.fullName, kind: AvatarKind.urgent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.patient.fullName,
                            style: HbText.headingSmall,
                          ),
                          Text(
                            [
                              if (view.ageSex.isNotEmpty) view.ageSex,
                              detail.patient.village,
                              detail.patient.shortId,
                            ].join(' · '),
                            style: HbText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const HbDivider(),
                const SizedBox(height: 14),
                DetailRow(
                  'Urgent case type',
                  '${visitTypeLabel(detail.visit.type)} warning signs',
                  valueColor: HbColors.red,
                ),
                const SizedBox(height: 12),
                DetailRow('Alert status', switch (state) {
                  DispatchState.confirmed => 'Confirmed',
                  DispatchState.sentSms => 'SMS sent',
                  DispatchState.unconfirmed => 'Not confirmed',
                  DispatchState.sending => 'Sending',
                }, valueColor: sent ? HbColors.brand : HbColors.warning),
              ],
            ),
          ),
          if (!internet)
            HbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full patient record', style: HbText.headingSmall),
                  const SizedBox(height: 4),
                  Text(
                    'The SMS carried the urgent details. The full record stays safe on this '
                    'phone and syncs when the internet returns.',
                    style: HbText.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  const StatusChip(
                    StatusKind.pending,
                    label: 'Waiting for internet sync',
                  ),
                ],
              ),
            ),
          if (unconfirmed) ...[
            HbButton.danger(
              'Resend SMS',
              icon: Icons.refresh,
              onPressed: () => unawaited(
                ref.read(urgentDispatcherProvider).sendSms(visitId),
              ),
            ),
            HbButton.secondary(
              'Call health centre',
              icon: Icons.call_outlined,
              onPressed: () => unawaited(
                launchUrl(Uri(scheme: 'tel', path: callNumber ?? '')),
              ),
            ),
          ],
          if (!readsAcks && (state == DispatchState.sentSms || unconfirmed))
            HbButton.secondary(
              'I got the confirmation',
              icon: Icons.check_circle_outline,
              onPressed: () => unawaited(
                ref.read(urgentDispatcherProvider).confirm(visitId),
              ),
            ),
          HbButton.primary(
            'Back to home',
            onPressed: () {
              ref.read(tabIndexProvider.notifier).state = 0;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
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
    );
  }
}

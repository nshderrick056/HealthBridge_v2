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

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: null),
      body: PageBody(
        children: [
          HbCard(
            color: HbColors.red,
            shadow: false,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${detail.patient.fullName} needs the health centre today',
                  style: HbText.headingLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    '${visitTypeLabel(detail.visit.type)} warning signs',
                    detail.patient.village,
                    detail.patient.shortId,
                  ].join(' · '),
                  style: HbText.bodySmall.copyWith(color: HbColors.onRed),
                ),
              ],
            ),
          ),
          const SectionHeading('Danger signs you recorded'),
          HbCard(
            child: Column(
              children: [
                for (final c in detail.signs)
                  BulletLine(labels[c] ?? c, HbColors.red),
              ],
            ),
          ),
          const SectionHeading('What happens next'),
          const HbCard(
            child: _Steps([
              'Send the alert below. It goes over the internet, or by SMS if there is none.',
              'Help the patient get to the health centre.',
              'A nurse may call you back. Keep your phone on.',
            ]),
          ),
          HbPill(
            online
                ? 'Online · the alert goes over the internet'
                : 'Offline · the alert will go by SMS',
            dot: online ? HbColors.brand : HbColors.amberMark,
          ),
          HbButton.danger(
            'Send urgent alert',
            icon: Icons.send_outlined,
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
    );
  }
}

/// Numbered steps in lime circles.
class _Steps extends StatelessWidget {
  const _Steps(this.steps);

  final List<String> steps;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (i, s) in steps.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: HbColors.lime,
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}', style: HbText.labelMedium),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s, style: HbText.bodyMedium)),
            ],
          ),
        ),
    ],
  );
}

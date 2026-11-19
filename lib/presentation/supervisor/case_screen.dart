import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/supervision.dart';
import '../view_models.dart';
import 'supervisor_controllers.dart';

/// One case for the supervisor (Figma v3 "Case detail"): the patient, the danger signs, the visit,
/// the CHW, the next steps the server allows, and the history. Stateful only to own the note.
class CaseScreen extends ConsumerStatefulWidget {
  const CaseScreen({super.key, required this.alertId});

  final String alertId;

  @override
  ConsumerState<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends ConsumerState<CaseScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _move(AlertStatus to) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(caseStatusProvider(widget.alertId).notifier)
        .move(to, _note.text);
    if (error == null) _note.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Case moved to ${to.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(caseProvider(widget.alertId));
    final saving = ref.watch(caseStatusProvider(widget.alertId));
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load this case.',
            style: HbText.bodyMedium.copyWith(color: HbColors.red),
          ),
        ),
        data: (d) => _body(d, saving),
      ),
    );
  }

  static String _action(AlertStatus to) => switch (to) {
    AlertStatus.escalated => 'Escalate',
    AlertStatus.followUp => 'Ask for follow-up',
    AlertStatus.resolved => 'Resolve',
    AlertStatus.reviewed => 'Mark reviewed',
    AlertStatus.newCase => to.label,
  };

  Widget _body(AlertDetail d, bool saving) {
    final s = d.summary;
    final open =
        s.status == AlertStatus.newCase || s.status == AlertStatus.escalated;
    final patientLine = [
      if (d.patientAge != null) '${d.patientAge} years',
      if (d.patientSex == 'F') 'Female',
      if (d.patientSex == 'M') 'Male',
      if (s.village != null && s.village!.isNotEmpty) s.village!,
      if (s.patientShortId != null) s.patientShortId!,
    ].join(' · ');
    // The first non-escalating step is the main one; escalating is always the red one.
    final primary = d.next.where((t) => t != AlertStatus.escalated).firstOrNull;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.patientName ?? 'Patient ${s.patientShortId ?? ''}',
          style: HbText.headingLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (patientLine.isNotEmpty) patientLine,
            'Case ${d.shortCode ?? ''}',
          ].join(' · '),
          style: HbText.bodySmall.copyWith(
            color: open ? HbColors.onRed : HbColors.onBrand,
          ),
        ),
        const SizedBox(height: 12),
        HbPill(
          s.status.label,
          background: Colors.white,
          foreground: open ? HbColors.red : HbColors.brand,
        ),
      ],
    );

    return PageBody(
      children: [
        Row(
          children: [
            HbCircleButton(
              icon: Icons.chevron_left,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        if (open)
          HbCard(color: HbColors.red, shadow: false, child: header)
        else
          HbGradientCard(child: header),
        if (s.isPartial)
          HbCard(
            color: HbColors.amberTint,
            shadow: false,
            child: Text(
              'This case came by SMS. The full record arrives when the CHW is back online.',
              style: HbText.bodyMedium.copyWith(color: HbColors.warning),
            ),
          ),
        if (s.dangerSigns.isNotEmpty) ...[
          const SectionHeading('Danger signs'),
          HbCard(
            child: Column(
              children: [
                for (final sign in s.dangerSigns)
                  BulletLine(sign, HbColors.red),
              ],
            ),
          ),
        ],
        const SectionHeading('Visit'),
        HbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.visitType != null) ...[
                DetailRow('Type', s.visitType!),
                const SizedBox(height: 12),
              ],
              if (d.recordedAt != null) ...[
                DetailRow(
                  'Recorded',
                  '${fullDate(d.recordedAt!)} ${clock(d.recordedAt!)}',
                ),
                const SizedBox(height: 12),
              ],
              DetailRow('Channel', s.channel == 'sms' ? 'SMS' : 'Internet'),
              if (d.answers['temperature'] != null) ...[
                const SizedBox(height: 12),
                DetailRow('Temperature', '${d.answers['temperature']} °C'),
              ],
              if (d.notes != null && d.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(d.notes!, style: HbText.bodyMedium),
              ],
            ],
          ),
        ),
        const SectionHeading('Community health worker'),
        HbCard(
          child: Column(
            children: [
              Row(
                children: [
                  HbAvatar(s.chwName ?? 'CHW', kind: AvatarKind.lime),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.chwName ?? 'Unknown',
                          style: HbText.headingSmall,
                        ),
                        if (d.chwPhone != null)
                          Text(d.chwPhone!, style: HbText.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (d.chwPhone != null && d.chwPhone!.isNotEmpty) ...[
                const SizedBox(height: 14),
                HbButton.secondary(
                  'Call the CHW',
                  icon: Icons.call_outlined,
                  onPressed: () => unawaited(
                    launchUrl(Uri(scheme: 'tel', path: d.chwPhone)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (d.next.isNotEmpty) ...[
          const SectionHeading('Take action'),
          HbCard(
            child: Column(
              children: [
                HbTextField(
                  label: 'Note for the case history (optional)',
                  hint: 'e.g. Referred to the hospital',
                  controller: _note,
                  maxLines: 2,
                ),
                for (final to in d.next) ...[
                  const SizedBox(height: 12),
                  if (to == AlertStatus.escalated)
                    HbButton.danger(
                      _action(to),
                      onPressed: saving ? null : () => _move(to),
                    )
                  else if (to == primary)
                    HbButton.primary(
                      _action(to),
                      onPressed: saving ? null : () => _move(to),
                    )
                  else
                    HbButton.secondary(
                      _action(to),
                      onPressed: saving ? null : () => _move(to),
                    ),
                ],
              ],
            ),
          ),
        ],
        if (d.events.isNotEmpty) ...[
          const SectionHeading('History'),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, e) in d.events.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Text(
                    '${e.from?.label ?? 'New'} → ${e.to.label}'
                    '${e.actor == null ? '' : ' by ${e.actor}'}',
                    style: HbText.labelMedium,
                  ),
                  if (e.at != null)
                    Text(
                      '${relativeDay(e.at!)} ${clock(e.at!)}',
                      style: HbText.bodySmall,
                    ),
                  if (e.note != null) Text(e.note!, style: HbText.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

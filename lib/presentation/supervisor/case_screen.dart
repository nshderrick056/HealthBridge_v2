import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/supervision.dart';
import '../view_models.dart';
import 'inbox_screen.dart';
import 'supervisor_controllers.dart';

/// One case for the supervisor (Figma supervisor frame 2): the visit, the patient, the danger signs,
/// who did what, and the next steps. Stateful only to own the note's text controller.
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
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load this case.',
            style: HbText.bodySmall.copyWith(color: HbColors.red),
          ),
        ),
        data: (d) => _body(d, saving),
      ),
    );
  }

  Widget _body(AlertDetail d, bool saving) {
    final s = d.summary;
    final patientLine = [
      if (d.patientAge != null) '${d.patientAge} years',
      if (d.patientSex == 'F') 'Female',
      if (d.patientSex == 'M') 'Male',
      if (s.village != null && s.village!.isNotEmpty) s.village!,
      if (s.patientShortId != null) s.patientShortId!,
    ].join(' · ');
    return PageBody(
      children: [
        PageHeader(
          title: s.patientName ?? 'Patient ${s.patientShortId ?? ''}',
          subtitle: 'Case ${d.shortCode ?? ''}',
          trailing: StatusTag(s.status),
        ),
        HbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient', style: HbText.labelMedium),
              const SizedBox(height: 6),
              Text(patientLine, style: HbText.bodySmall),
              if (s.isPartial) ...[
                const SizedBox(height: 6),
                Text(
                  'This case came by SMS. The full record arrives when the CHW is back online.',
                  style: HbText.bodySmall.copyWith(color: HbColors.warning),
                ),
              ],
            ],
          ),
        ),
        HbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visit', style: HbText.labelMedium),
              const SizedBox(height: 8),
              if (s.visitType != null) DetailRow('Type', s.visitType!),
              if (d.recordedAt != null) ...[
                const SizedBox(height: 6),
                DetailRow(
                  'Recorded',
                  '${fullDate(d.recordedAt!)} ${clock(d.recordedAt!)}',
                ),
              ],
              const SizedBox(height: 6),
              DetailRow('Channel', s.channel == 'sms' ? 'SMS' : 'Internet'),
              if (d.answers['temperature'] != null) ...[
                const SizedBox(height: 6),
                DetailRow('Temperature', '${d.answers['temperature']} °C'),
              ],
              if (s.dangerSigns.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Danger signs',
                  style: HbText.labelSmall.copyWith(color: HbColors.red),
                ),
                for (final sign in s.dangerSigns)
                  BulletLine(sign, HbColors.red),
              ],
              if (d.notes != null && d.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(d.notes!, style: HbText.bodySmall),
              ],
            ],
          ),
        ),
        HbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Community health worker', style: HbText.labelMedium),
              const SizedBox(height: 6),
              Text(
                [s.chwName ?? '', d.chwPhone ?? ''].join(' · '),
                style: HbText.bodySmall,
              ),
            ],
          ),
        ),
        if (d.next.isNotEmpty) ...[
          HbTextField(
            label: 'Note (optional)',
            hint: 'e.g. Referred to the hospital',
            controller: _note,
            maxLines: 2,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final to in d.next)
                FilledButton(
                  onPressed: saving ? null : () => _move(to),
                  style: FilledButton.styleFrom(
                    backgroundColor: to == AlertStatus.escalated
                        ? HbColors.red
                        : HbColors.teal,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(switch (to) {
                    AlertStatus.escalated => 'Escalate',
                    AlertStatus.followUp => 'Ask for follow-up',
                    AlertStatus.resolved => 'Resolve',
                    AlertStatus.reviewed => 'Mark reviewed',
                    AlertStatus.newCase => to.label,
                  }),
                ),
            ],
          ),
        ],
        if (d.events.isNotEmpty)
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('History', style: HbText.labelMedium),
                for (final e in d.events) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${e.from?.label ?? 'New'} → ${e.to.label}'
                    '${e.actor == null ? '' : ' by ${e.actor}'}'
                    '${e.at == null ? '' : ' · ${relativeDay(e.at!)} ${clock(e.at!)}'}',
                    style: HbText.bodySmall.copyWith(
                      color: HbColors.textPrimary,
                    ),
                  ),
                  if (e.note != null) Text(e.note!, style: HbText.bodySmall),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

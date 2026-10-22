import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(allPatientsProvider).value ?? const <Patient>[];
    final visits = ref.watch(allVisitsProvider).value ?? const <Visit>[];
    final online = ref.watch(isOnlineProvider);
    final counts = syncCounts(patients, visits);
    final recent = ([
      ...visits,
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt))).take(8).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      bottomNavigationBar: const SubPageNav(current: 0),
      body: PageBody(
        children: [
          const PageHeader(
            title: 'Sync status',
            subtitle: 'Record transmission at a glance',
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: online ? HbColors.greenTint : HbColors.neutralTint,
              borderRadius: BorderRadius.circular(12),
              border: online ? Border.all(color: HbColors.green) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: online ? HbColors.green : HbColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: HbText.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: online ? HbColors.green : HbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    online
                        ? 'Pending records are syncing automatically'
                        : 'Records sync when internet returns',
                    overflow: TextOverflow.ellipsis,
                    style: HbText.bodySmall.copyWith(
                      color: online ? HbColors.green : HbColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SummaryRow(
            children: [
              Expanded(
                child: SummaryCard(
                  icon: Icons.person_outline,
                  tint: HbColors.greenTint,
                  color: HbColors.green,
                  value: counts.synced,
                  label: 'Synced',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryCard(
                  icon: Icons.calendar_today_outlined,
                  tint: HbColors.amberTint,
                  color: HbColors.warning,
                  value: counts.pending,
                  label: 'Pending',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryCard(
                  icon: Icons.error_outline,
                  tint: HbColors.redTint,
                  color: HbColors.red,
                  value: counts.failed,
                  label: 'Failed',
                ),
              ),
            ],
          ),
          Column(
            children: [
              const SectionHeading('Recent records', bold: true),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nothing recorded yet.', style: HbText.bodySmall),
                ),
              for (final v in recent)
                _row(
                  ref,
                  v,
                  patients.where((p) => p.id == v.patientId).firstOrNull,
                ),
            ],
          ),
          Text(
            'Records stay safely on this device until transmission is complete.',
            textAlign: TextAlign.center,
            style: HbText.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _row(WidgetRef ref, Visit v, Patient? p) {
    final failed = v.syncState == SyncState.failed;
    final (kind, label) = switch (v.syncState) {
      SyncState.synced => (StatusKind.synced, null),
      SyncState.failed => (StatusKind.failed, null),
      _ => (StatusKind.pending, null),
    };
    final at = v.recordedAt.toLocal();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HbColors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: failed ? HbColors.redTint : HbColors.tealTint,
            child: Text(
              failed ? '!' : '\u21BB',
              style: HbText.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: failed ? HbColors.red : HbColors.teal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.fullName ?? 'Unknown patient',
                  style: HbText.labelMedium,
                ),
                const SizedBox(height: 3),
                Text(visitTypeLabel(v.type), style: HbText.bodySmall),
                const SizedBox(height: 3),
                Text(
                  '${relativeDay(at)} \u00B7 ${clock(at)}',
                  style: HbText.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(kind, label: label),
              if (failed) ...[
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () => ref.read(visitsRepositoryProvider).retry(v.id),
                  child: Text(
                    'Retry',
                    style: HbText.labelSmall.copyWith(color: HbColors.teal),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

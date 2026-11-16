import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../sync/sync_service.dart';
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
    String n(int c) => c == 1 ? '1 record' : '$c records';

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 0),
      body: PageBody(
        children: [
          const HbStepBar(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sync', style: HbText.headingLarge),
              const SizedBox(height: 4),
              Text(
                online
                    ? 'Online · waiting records send by themselves'
                    : 'Offline · records send when the internet returns',
                style: HbText.bodySmall,
              ),
            ],
          ),
          HbCard(
            child: Column(
              children: [
                DetailRow('Sent', n(counts.synced)),
                const SizedBox(height: 12),
                DetailRow(
                  'Waiting',
                  n(counts.pending),
                  valueColor: counts.pending > 0 ? HbColors.warning : null,
                ),
                const SizedBox(height: 12),
                DetailRow(
                  'Failed',
                  n(counts.failed),
                  valueColor: counts.failed > 0 ? HbColors.red : null,
                ),
              ],
            ),
          ),
          HbButton.secondary(
            'Send now',
            icon: Icons.sync,
            onPressed: online ? () => ref.read(syncNowProvider)() : null,
          ),
          const SectionHeading('Recent records'),
          if (recent.isEmpty)
            Text('Nothing recorded yet.', style: HbText.bodySmall)
          else
            HbCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, v) in recent.indexed) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: HbDivider(),
                      ),
                    _row(
                      ref,
                      v,
                      patients.where((p) => p.id == v.patientId).firstOrNull,
                    ),
                  ],
                ],
              ),
            ),
          Text(
            'Records stay safely on this phone until the server has them.',
            style: HbText.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _row(WidgetRef ref, Visit v, Patient? p) {
    final failed = v.syncState == SyncState.failed;
    final at = v.recordedAt.toLocal();
    final name = p?.fullName ?? 'Unknown patient';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          HbAvatar(
            name,
            kind: failed || v.isUrgent ? AvatarKind.urgent : AvatarKind.plain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: HbText.headingSmall),
                Text(
                  '${visitTypeLabel(v.type)} · ${relativeDay(at)} ${clock(at)}',
                  style: HbText.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (failed)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await ref.read(visitsRepositoryProvider).retry(v.id);
                await ref.read(syncNowProvider)();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  'Retry',
                  style: HbText.labelMedium.copyWith(
                    color: HbColors.red,
                    decoration: TextDecoration.underline,
                    decorationColor: HbColors.red,
                  ),
                ),
              ),
            )
          else
            Text(
              v.syncState == SyncState.synced ? 'Sent' : 'Waiting',
              style: HbText.labelMedium.copyWith(
                color: v.syncState == SyncState.synced
                    ? HbColors.brand
                    : HbColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

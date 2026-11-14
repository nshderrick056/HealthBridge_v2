import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';
import '../sync/sync_status_screen.dart';
import '../view_models.dart';

class RecordSavedScreen extends ConsumerWidget {
  const RecordSavedScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId)).value;
    final online = ref.watch(isOnlineProvider);
    if (detail == null) return const Scaffold(body: SizedBox.shrink());
    final synced = detail.visit.syncState == SyncState.synced;
    final recorded = detail.visit.recordedAt.toLocal();

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: null),
      body: PageBody(
        children: [
          PageHeader(
            title: 'Record saved',
            subtitle: online
                ? 'Saved on this device'
                : 'Saved safely while offline',
          ),
          const NoticeCard(
            color: HbColors.green,
            tint: HbColors.greenTint,
            glyph: '\u2713',
            title: 'Visit record saved successfully',
            body: 'The record is stored safely on this device. No information was lost.',
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: HbColors.neutralTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? 'Online' : 'Offline mode',
                        style: HbText.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        online
                            ? 'Syncing will start shortly'
                            : 'Automatic sync will begin when internet returns',
                        style: HbText.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(online ? StatusKind.online : StatusKind.offline),
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
                    Text('Saved record', style: HbText.labelMedium),
                    StatusChip(synced ? StatusKind.synced : StatusKind.pending),
                  ],
                ),
                const SizedBox(height: 8),
                Text(detail.patient.fullName, style: HbText.headingLarge),
                const SizedBox(height: 8),
                Text(
                  '${detail.patient.shortId} \u00B7 ${detail.patient.village}',
                  style: HbText.bodySmall,
                ),
                const SizedBox(height: 8),
                const HbDivider(),
                const SizedBox(height: 8),
                DetailRow('Visit type', visitTypeLabel(detail.visit.type)),
                const SizedBox(height: 8),
                DetailRow(
                  'Recorded',
                  '${fullDate(recorded)} \u00B7 ${clock(recorded)}',
                ),
                const SizedBox(height: 8),
                DetailRow(
                  'Sync status',
                  synced ? 'Synced' : 'Pending sync',
                  valueColor: synced ? HbColors.green : HbColors.warning,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HbColors.tealTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync, size: 16, color: HbColors.teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep working as normal. HealthBridge will sync this record automatically when a connection is available.',
                    style: HbText.bodySmall,
                  ),
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
                'View pending records',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SyncStatusScreen(),
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

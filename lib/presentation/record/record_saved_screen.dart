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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Visit saved',
                style: HbText.headingLarge.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 4),
              Text(
                '${detail.patient.fullName} · '
                '${visitTypeLabel(detail.visit.type)} · ${clock(recorded)}',
                style: HbText.bodySmall,
              ),
              const SizedBox(height: 10),
              const HbPill(
                'Saved on this phone',
                icon: Icons.check,
                foreground: HbColors.brand,
              ),
            ],
          ),
          HbCard(
            child: Column(
              children: [
                DetailRow(
                  'Sent to the server',
                  synced
                      ? 'Yes'
                      : (online ? 'Sending now' : 'Not yet, no signal'),
                  valueColor: synced ? HbColors.brand : HbColors.warning,
                ),
                const SizedBox(height: 12),
                DetailRow('Patient ID', detail.patient.shortId),
                const SizedBox(height: 12),
                DetailRow('Village', detail.patient.village),
                const SizedBox(height: 12),
                DetailRow(
                  'Recorded',
                  '${fullDate(recorded)} · ${clock(recorded)}',
                ),
              ],
            ),
          ),
          Text(
            'It sends by itself when the phone has signal. You can keep working; '
            'nothing is lost if the phone turns off.',
            style: HbText.bodyMedium.copyWith(color: HbColors.muted),
          ),
          HbButton.primary(
            'Back to home',
            onPressed: () {
              ref.read(tabIndexProvider.notifier).state = 0;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          HbButton.secondary(
            'View pending records',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SyncStatusScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

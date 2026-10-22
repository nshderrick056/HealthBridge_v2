import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../record/record_visit_screen.dart';
import '../shell/app_shell.dart';
import '../sync/sync_status_screen.dart';
import '../view_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final online = ref.watch(isOnlineProvider);
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final dispatches = ref.watch(allDispatchesProvider).value ?? const [];
    final views = buildPatientViews(patients, visits);
    final now = DateTime.now();
    final today = visits
        .where((v) => sameDay(v.recordedAt.toLocal(), now))
        .toList();
    final counts = syncCounts(patients, visits);
    final smsSent = dispatches
        .where(
          (d) =>
              d.state == DispatchState.sentSms ||
              d.state == DispatchState.confirmed,
        )
        .length;
    final recent = ([
      ...visits,
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt))).take(2).toList();
    final name = session?.fullName ?? '';
    final first = name.split(' ').first;
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');

    return PageBody(
      children: [
        PageHeader(
          title: first.isEmpty ? greeting : '$greeting, $first',
          subtitle: 'Community Health Worker',
          trailing: CircleAvatar(
            radius: 20,
            backgroundColor: HbColors.teal,
            child: Text(
              initials(name),
              style: HbText.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
              Text(
                online
                    ? 'Connection available'
                    : 'Records are saved on this device',
                style: HbText.bodySmall.copyWith(
                  color: online ? HbColors.green : HbColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        HbButton.primary(
          'Record new visit',
          icon: Icons.add_circle_outline,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RecordVisitScreen()),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\u2019s summary', style: HbText.sectionBold),
            const SizedBox(height: 7),
            SummaryRow(
              children: [
                Expanded(
                  child: SummaryCard(
                    icon: Icons.person_outline,
                    tint: HbColors.greenTint,
                    color: HbColors.green,
                    value: today.map((v) => v.patientId).toSet().length,
                    label: 'Patients visited',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryCard(
                    icon: Icons.calendar_today_outlined,
                    tint: HbColors.amberTint,
                    color: HbColors.warning,
                    value: views
                        .where((v) => v.status == StatusKind.followUp)
                        .length,
                    label: 'Follow-ups due',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryCard(
                    icon: Icons.error_outline,
                    tint: HbColors.redTint,
                    color: HbColors.red,
                    value: today.where((v) => v.isUrgent).length,
                    label: 'Urgent cases',
                  ),
                ),
              ],
            ),
          ],
        ),
        HbCard(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.smartphone,
                    size: 19,
                    color: HbColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Sync status', style: HbText.sectionBold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncStatusScreen(),
                      ),
                    ),
                    child: Text(
                      'View',
                      style: HbText.labelSmall.copyWith(color: HbColors.teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _syncMessage(
                      '${counts.pending}',
                      'records waiting to sync',
                      HbColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _syncMessage(
                      '$smsSent',
                      'urgent alert${smsSent == 1 ? '' : 's'} sent by SMS',
                      HbColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            SectionHeading(
              'Recent patients',
              bold: true,
              action: 'See all',
              onAction: () => ref.read(tabIndexProvider.notifier).state = 1,
            ),
            const SizedBox(height: 2),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No visits recorded yet.', style: HbText.bodySmall),
              ),
            for (final v in recent) _recentRow(patients, v),
          ],
        ),
      ],
    );
  }

  Widget _syncMessage(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: HbText.headingSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: HbText.bodySmall.copyWith(fontSize: 11, height: 1.3)),
    ],
  );

  Widget _recentRow(List patients, visit) {
    final p = patients.firstWhere((p) => p.id == visit.patientId);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: HbColors.tealTint,
            child: Text(
              initials(p.fullName),
              style: HbText.labelSmall.copyWith(
                color: HbColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.fullName, style: HbText.labelMedium),
                const SizedBox(height: 2),
                Text(
                  '${visitTypeLabel(visit.type)} \u00B7 ${p.village}',
                  style: HbText.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            sameDay(visit.recordedAt.toLocal(), DateTime.now())
                ? clock(visit.recordedAt.toLocal())
                : relativeDay(visit.recordedAt.toLocal()),
            style: HbText.bodySmall,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../patients/patient_profile_screen.dart';
import '../shell/app_shell.dart';
import '../sync/sync_status_screen.dart';
import '../view_models.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

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
    final today =
        visits.where((v) => sameDay(v.recordedAt.toLocal(), now)).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final visited = today.map((v) => v.patientId).toSet().length;
    final due = views
        .where(
          (v) =>
              v.status == StatusKind.followUp ||
              v.status == StatusKind.attention,
        )
        .toList();
    final urgent = today.where((v) => v.isUrgent).toList();
    final pending = syncCounts(patients, visits).pending;
    Patient? patientOf(String id) =>
        patients.where((p) => p.id == id).firstOrNull;
    void openPatient(String id) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientProfileScreen(patientId: id),
      ),
    );

    return PageBody(
      children: [
        ProfileHeader(
          name: session?.fullName ?? '',
          role: 'Community Health Worker',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: HbText.headingLarge),
            const SizedBox(height: 4),
            Text(
              '${_weekdays[now.weekday - 1]} ${dayMonth(now)} · '
              '$visited visited, ${due.length} due',
              style: HbText.bodySmall,
            ),
            const SizedBox(height: 10),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SyncStatusScreen(),
                  ),
                ),
                child: HbPill(
                  _connection(online, pending),
                  dot: online ? HbColors.brand : HbColors.amberMark,
                ),
              ),
            ),
          ],
        ),
        if (urgent.isNotEmpty)
          _UrgentCard(
            count: urgent.length,
            name: patientOf(urgent.first.patientId)?.fullName ?? 'A patient',
            state: dispatches
                .where((d) => d.visitId == urgent.first.id)
                .firstOrNull
                ?.state,
            onTap: () => ref.read(tabIndexProvider.notifier).state = 3,
          ),
        SectionHeading(
          'Due today',
          action: 'View all',
          onAction: () => ref.read(tabIndexProvider.notifier).state = 1,
        ),
        if (due.isEmpty)
          Text('Nobody is due for a visit.', style: HbText.bodySmall)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, v) in due.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: 264,
                    child: _DueCard(
                      view: v,
                      onTap: () => openPatient(v.patient.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SectionHeading('Visited today'),
        if (today.isEmpty)
          Text('No visits recorded yet.', style: HbText.bodySmall)
        else
          HbCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, visit) in today.indexed) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: HbDivider(),
                    ),
                  _VisitRow(
                    visit: visit,
                    patient: patientOf(visit.patientId),
                    onTap: () => openPatient(visit.patientId),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _connection(bool online, int pending) {
    final waiting = pending == 1 ? '1 visit' : '$pending visits';
    if (online) {
      return pending == 0 ? 'Online · all sent' : 'Online · sending $waiting';
    }
    return pending == 0
        ? 'Offline · nothing waiting'
        : 'Offline · $waiting not sent yet';
  }
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({
    required this.count,
    required this.name,
    required this.state,
    required this.onTap,
  });

  final int count;
  final String name;
  final DispatchState? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alert = switch (state) {
      DispatchState.confirmed => 'the health centre has the alert',
      DispatchState.sentSms ||
      DispatchState.unconfirmed => 'alert sent by SMS, not confirmed yet',
      DispatchState.sending => 'alert is sending',
      null => 'alert not sent yet',
    };
    return HbCard(
      color: HbColors.red,
      shadow: false,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 urgent case today'
                      : '$count urgent cases today',
                  style: HbText.headingSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name · $alert',
                  style: HbText.bodySmall.copyWith(color: HbColors.onRed),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.view, required this.onTap});

  final PatientView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = view.latest;
    final reason = view.status == StatusKind.attention
        ? 'Needs attention'
        : latest == null
        ? 'Follow-up'
        : '${visitTypeLabel(latest.type)} follow-up';
    return HbGradientCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: HbText.labelMedium.copyWith(
              color: HbColors.lime,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            view.patient.fullName,
            style: HbText.headingLarge.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          Text(
            [
              if (view.ageSex.isNotEmpty) view.ageSex,
              view.patient.village,
            ].join(' · '),
            style: HbText.bodySmall.copyWith(color: HbColors.onBrand),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              HbAvatar(view.patient.fullName, kind: AvatarKind.lime, size: 36),
              const SizedBox(width: 10),
              Text(
                'Due ${view.status == StatusKind.attention ? 'now' : 'today'}',
                style: HbText.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({
    required this.visit,
    required this.patient,
    required this.onTap,
  });

  final Visit visit;
  final Patient? patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = patient?.fullName ?? 'Unknown patient';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            HbAvatar(
              name,
              kind: visit.isUrgent ? AvatarKind.urgent : AvatarKind.plain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HbText.headingSmall),
                  Text(
                    [visitTypeLabel(visit.type), ?patient?.village].join(' · '),
                    style: HbText.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(clock(visit.recordedAt.toLocal()), style: HbText.bodySmall),
            const Icon(Icons.chevron_right, color: HbColors.chevron),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../domain/entities/supervision.dart';
import '../view_models.dart';

final chwHistoryProvider = FutureProvider.autoDispose
    .family<ChwHistory, String>(
      (ref, id) => ref.watch(supervisionRepositoryProvider).chw(id),
    );

final patientHistoryProvider = FutureProvider.autoDispose
    .family<PatientHistory, String>(
      (ref, id) => ref.watch(supervisionRepositoryProvider).patient(id),
    );

/// The supervisor's patient search text.
class PatientSearchController extends Notifier<String> {
  @override
  String build() => '';

  void search(String text) => state = text.trim();
}

final patientSearchProvider = NotifierProvider<PatientSearchController, String>(
  PatientSearchController.new,
);

final centrePatientsProvider = FutureProvider.autoDispose<List<PatientRow>>((
  ref,
) async {
  final query = ref.watch(patientSearchProvider);
  final repo = ref.watch(supervisionRepositoryProvider);
  // Wait for typing to pause; a newer query rebuilds this provider, so the old one stops here.
  if (query.isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!ref.mounted) return const [];
  }
  return repo.patients(query: query);
});

const _visitType = {
  'maternal': 'Maternal Health',
  'child': 'Child Health',
  'malaria': 'Malaria',
  'nutrition': 'Malnutrition',
};

String _when(DateTime? d) => d == null ? '' : '${relativeDay(d)} ${clock(d)}';

Widget _loading() => const Padding(
  padding: EdgeInsets.all(24),
  child: Center(child: CircularProgressIndicator()),
);

Widget _failed(Object e, String what) => HbCard(
  child: Text(
    e.toString().contains('not_found')
        ? 'This $what does not exist or belongs to another health centre.'
        : 'Could not load this $what. Check your connection.',
    style: HbText.bodyMedium.copyWith(color: HbColors.red),
  ),
);

Widget _backRow(BuildContext context) => Row(
  children: [
    HbCircleButton(
      icon: Icons.chevron_left,
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  ],
);

/// One visit with everything recorded. [onPatient] links the patient on a CHW's history.
class HistoryVisitCard extends StatelessWidget {
  const HistoryVisitCard({super.key, required this.visit, this.onPatient});

  final HistoryVisit visit;
  final VoidCallback? onPatient;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    return HbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _visitType[v.type] ?? 'Visit',
                      style: HbText.headingSmall,
                    ),
                    Text(_when(v.recordedAt), style: HbText.bodySmall),
                  ],
                ),
              ),
              if (v.isUrgent) const StatusChip(StatusKind.urgent),
            ],
          ),
          if (onPatient != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: onPatient,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  v.patientName ?? 'Patient ${v.patientShortId ?? ''}',
                  style: HbText.labelMedium.copyWith(
                    color: HbColors.brand,
                    decoration: TextDecoration.underline,
                    decorationColor: HbColors.brand,
                  ),
                ),
              ),
            ),
          ],
          if (v.isPartial)
            Text(
              'Came by SMS; the full record is not here yet.',
              style: HbText.bodySmall.copyWith(color: HbColors.warning),
            ),
          if (v.dangerSigns.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final s in v.dangerSigns) BulletLine(s, HbColors.red),
          ],
          if (v.temperature != null ||
              v.condition != null ||
              v.followUpOn != null) ...[
            const SizedBox(height: 8),
            if (v.temperature != null)
              DetailRow('Temperature', '${v.temperature} °C'),
            if (v.condition != null) ...[
              const SizedBox(height: 6),
              DetailRow('Condition', v.condition!),
            ],
            if (v.followUpOn != null) ...[
              const SizedBox(height: 6),
              DetailRow('Follow-up', fullDate(v.followUpOn!)),
            ],
          ],
          if (v.symptoms != null) ...[
            const SizedBox(height: 8),
            Text('Symptoms', style: HbText.bodySmall),
            Text(v.symptoms!, style: HbText.bodyMedium),
          ],
          if (v.notes != null) ...[
            const SizedBox(height: 8),
            Text('Notes', style: HbText.bodySmall),
            Text(v.notes!, style: HbText.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// A CHW of the centre and every visit they recorded.
class ChwHistoryScreen extends ConsumerWidget {
  const ChwHistoryScreen({super.key, required this.chwId});

  final String chwId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(chwHistoryProvider(chwId));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(chwHistoryProvider(chwId).future),
        child: PageBody(
          children: [
            _backRow(context),
            ...history.when(
              loading: () => [_loading()],
              error: (e, _) => [_failed(e, 'CHW')],
              data: (h) => [
                Row(
                  children: [
                    HbAvatar(h.chw.name, kind: AvatarKind.lime, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.chw.name, style: HbText.headingLarge),
                          Text(
                            [
                              if (h.chw.chwRole != null)
                                h.chw.chwRole!.toUpperCase(),
                              ?h.chw.village,
                              ?h.chw.phone,
                            ].join(' · '),
                            style: HbText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SectionHeading('Visits (${h.visits.length})'),
                if (h.visits.isEmpty)
                  Text('No visits recorded yet.', style: HbText.bodySmall),
                for (final v in h.visits)
                  HistoryVisitCard(
                    visit: v,
                    onPatient: v.patientId == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SupervisorPatientScreen(
                                patientId: v.patientId!,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The centre's patients, latest visit first, with search (the supervisor's Patients tab).
class SupervisorPatientsScreen extends ConsumerWidget {
  const SupervisorPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(centrePatientsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(centrePatientsProvider.future),
      child: PageBody(
        children: [
          const PageHeader(
            title: 'Patients',
            subtitle: 'Everyone your CHWs follow, latest visit first',
          ),
          TextField(
            onChanged: ref.read(patientSearchProvider.notifier).search,
            style: HbText.bodyMedium.copyWith(fontSize: 17),
            decoration: const InputDecoration(
              hintText: 'Name, patient ID or village',
              prefixIcon: Icon(Icons.search, size: 20, color: HbColors.muted),
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          ...patients.when(
            loading: () => [_loading()],
            error: (e, _) => [_failed(e, 'list')],
            data: (list) => [
              if (list.isEmpty)
                HbCard(
                  child: Text(
                    ref.read(patientSearchProvider).isEmpty
                        ? 'No patients registered yet.'
                        : 'No patients match.',
                    style: HbText.bodyMedium.copyWith(color: HbColors.muted),
                  ),
                )
              else
                HbCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, p) in list.indexed) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: HbDivider(),
                          ),
                        _PatientRowTile(
                          patient: p,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SupervisorPatientScreen(patientId: p.id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientRowTile extends StatelessWidget {
  const _PatientRowTile({required this.patient, required this.onTap});

  final PatientRow patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final name = p.name ?? 'Name not received yet';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            HbAvatar(
              p.name ?? p.shortId ?? '?',
              kind: p.lastVisitUrgent ? AvatarKind.urgent : AvatarKind.plain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HbText.headingSmall),
                  Text(
                    [?p.ageSex, ?p.village, ?p.shortId].join(' · '),
                    style: HbText.bodySmall,
                  ),
                  Text(
                    [
                      if (p.chwName != null) 'CHW ${p.chwName}',
                      p.lastVisitAt == null
                          ? 'No visits'
                          : 'Last visit ${relativeDay(p.lastVisitAt!)}',
                    ].join(' · '),
                    style: HbText.bodySmall,
                  ),
                ],
              ),
            ),
            if (p.lastVisitUrgent) ...[
              const SizedBox(width: 8),
              Text(
                'Urgent',
                style: HbText.labelMedium.copyWith(color: HbColors.red),
              ),
            ],
            const Icon(Icons.chevron_right, color: HbColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// One patient of the centre: profile, CHW, and every visit with what was recorded.
class SupervisorPatientScreen extends ConsumerWidget {
  const SupervisorPatientScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(patientHistoryProvider(patientId));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(patientHistoryProvider(patientId).future),
        child: PageBody(
          children: [
            _backRow(context),
            ...history.when(
              loading: () => [_loading()],
              error: (e, _) => [_failed(e, 'patient')],
              data: (h) {
                final p = h.patient;
                final urgent = h.visits.isNotEmpty && h.visits.first.isUrgent;
                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HbAvatar(
                          p.name ?? p.shortId ?? '?',
                          kind: AvatarKind.lime,
                          size: 56,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name ?? 'Name not received yet',
                                style: HbText.headingLarge.copyWith(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              ),
                              Text(
                                [
                                  ?p.ageSex,
                                  ?p.village,
                                  ?p.shortId,
                                  if (h.archived) 'archived by the CHW',
                                ].join(' · '),
                                style: HbText.bodySmall.copyWith(
                                  color: urgent
                                      ? HbColors.onRed
                                      : HbColors.onBrand,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (urgent) ...[
                      const SizedBox(height: 12),
                      Text(
                        'The latest visit was urgent.',
                        style: HbText.headingSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                );
                return [
                  if (urgent)
                    HbCard(color: HbColors.red, shadow: false, child: header)
                  else
                    HbGradientCard(child: header),
                  HbCard(
                    child: Row(
                      children: [
                        HbAvatar(p.chwName ?? 'CHW', kind: AvatarKind.lime),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.chwName ?? 'Unknown CHW',
                                style: HbText.headingSmall,
                              ),
                              Text(
                                ['CHW', ?h.chwPhone].join(' · '),
                                style: HbText.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (h.chwId != null)
                          IconButton(
                            tooltip: 'Open the CHW',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ChwHistoryScreen(chwId: h.chwId!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SectionHeading('Visits (${h.visits.length})'),
                  if (h.visits.isEmpty)
                    Text('No visits recorded yet.', style: HbText.bodySmall),
                  for (final v in h.visits) HistoryVisitCard(visit: v),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

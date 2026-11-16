import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../view_models.dart';
import 'patient_profile_screen.dart';
import 'patients_controller.dart';
import 'register_patient_screen.dart';

class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final views = ref.watch(visiblePatientsProvider);
    final query = ref.watch(patientsQueryProvider);
    final controller = ref.read(patientsQueryProvider.notifier);
    // One card per village, villages in alphabetical order.
    final byVillage = <String, List<PatientView>>{};
    for (final v in views) {
      (byVillage[v.patient.village] ??= []).add(v);
    }
    final villages = byVillage.keys.toList()..sort();

    return PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Patients', style: HbText.headingLarge),
            const SizedBox(width: 10),
            Text(
              '${patients.length}',
              style: HbText.headingMedium.copyWith(
                color: HbColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        TextField(
          onChanged: controller.search,
          style: HbText.bodyMedium.copyWith(fontSize: 17),
          decoration: const InputDecoration(
            hintText: 'Search by name or village',
            prefixIcon: Icon(Icons.search, size: 20, color: HbColors.muted),
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (f, label) in const [
              (PatientFilter.all, 'All'),
              (PatientFilter.followUp, 'Follow-up due'),
              (PatientFilter.urgent, 'Urgent'),
            ])
              ChoiceChipPill(
                label: label,
                selected: query.filter == f,
                onTap: () => controller.filterBy(f),
              ),
          ],
        ),
        if (views.isEmpty)
          HbCard(
            padding: const EdgeInsets.all(22),
            child: Text(
              patients.isEmpty
                  ? 'No patients yet. Register your first patient.'
                  : 'No patients match.',
              style: HbText.bodyMedium.copyWith(color: HbColors.muted),
            ),
          ),
        for (final village in villages)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '$village · ${byVillage[village]!.length}',
                  style: HbText.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              HbCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final (i, v) in byVillage[village]!.indexed) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: HbDivider(),
                        ),
                      PatientRow(
                        view: v,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PatientProfileScreen(patientId: v.patient.id),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        HbButton.primary(
          'Register patient',
          icon: Icons.add,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RegisterPatientScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar coloured by status, name, details, and one status word when it means something.
class PatientRow extends StatelessWidget {
  const PatientRow({super.key, required this.view, required this.onTap});

  final PatientView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = view.status;
    final (_, color, word) = StatusChip.style(status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            HbAvatar(view.patient.fullName, kind: avatarFor(status)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view.patient.fullName, style: HbText.headingSmall),
                  Text(
                    view.ageSex.isEmpty ? view.patient.shortId : view.ageSex,
                    style: HbText.bodySmall,
                  ),
                  Text('Last visit: ${view.when}', style: HbText.bodySmall),
                ],
              ),
            ),
            if (status != StatusKind.stable) ...[
              const SizedBox(width: 8),
              Text(word, style: HbText.labelMedium.copyWith(color: color)),
            ],
            const Icon(Icons.chevron_right, color: HbColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// A choice among a few (filters, visit types): dark pill when chosen, white when not.
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? HbColors.ink : HbColors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(
              label,
              style: HbText.bodyMedium.copyWith(
                color: selected ? Colors.white : HbColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

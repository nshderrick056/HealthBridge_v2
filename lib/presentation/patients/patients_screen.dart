import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
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

    return PageBody(
      children: [
        PageHeader(
          title: 'Patients',
          subtitle:
              '${patients.length} ${patients.length == 1 ? 'person' : 'people'} in your care',
        ),
        TextField(
          onChanged: controller.search,
          style: HbText.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search by name or village',
            hintStyle: HbText.bodyMedium.copyWith(
              color: HbColors.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.person_search_outlined,
              size: 19,
              color: HbColors.textSecondary,
            ),
            filled: true,
            fillColor: HbColors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HbColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HbColors.teal),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                patients.isEmpty
                    ? 'No patients yet. Register your first patient.'
                    : 'No patients match.',
                style: HbText.bodySmall,
              ),
            ),
          ),
        for (final v in views)
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: PatientCard(
              name: v.patient.fullName,
              detail: v.ageSex.isEmpty ? v.patient.shortId : v.ageSex,
              status: v.status,
              village: v.patient.village,
              when: v.when,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PatientProfileScreen(patientId: v.patient.id),
                ),
              ),
            ),
          ),
        HbButton.primary(
          'Register patient',
          icon: Icons.add_circle_outline,
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

/// The pill used for filters and visit types (selected = teal fill).
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? HbColors.teal : HbColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? HbColors.teal : HbColors.border),
      ),
      child: Text(
        label,
        style: HbText.labelSmall.copyWith(
          color: selected ? Colors.white : HbColors.textSecondary,
        ),
      ),
    ),
  );
}

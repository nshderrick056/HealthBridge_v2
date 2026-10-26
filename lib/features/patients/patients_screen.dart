import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../view_models.dart';
import 'patient_profile_screen.dart';
import 'register_patient_screen.dart';

enum _Filter { all, followUp, urgent }

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  var _filter = _Filter.all;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const [];
    final q = _query.trim().toLowerCase();
    final views =
        buildPatientViews(patients, visits).where((v) {
            final matches =
                q.isEmpty ||
                v.patient.fullName.toLowerCase().contains(q) ||
                v.patient.village.toLowerCase().contains(q) ||
                v.patient.shortId.toLowerCase().contains(q);
            final ok = switch (_filter) {
              _Filter.all => true,
              _Filter.followUp => v.status == StatusKind.followUp,
              _Filter.urgent => v.status == StatusKind.urgent,
            };
            return matches && ok;
          }).toList()
          ..sort((a, b) => a.patient.fullName.compareTo(b.patient.fullName));

    return PageBody(
      children: [
        PageHeader(
          title: 'Patients',
          subtitle:
              '${patients.length} ${patients.length == 1 ? 'person' : 'people'} in your care',
        ),
        TextField(
          onChanged: (v) => setState(() => _query = v),
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
              (_Filter.all, 'All'),
              (_Filter.followUp, 'Follow-up due'),
              (_Filter.urgent, 'Urgent'),
            ])
              ChoiceChipPill(
                label: label,
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../view_models.dart';

enum PatientFilter { all, followUp, urgent }

class PatientsQuery {
  const PatientsQuery({this.text = '', this.filter = PatientFilter.all});

  final String text;
  final PatientFilter filter;
}

/// The Patients tab's search box and filter pills.
class PatientsQueryController extends Notifier<PatientsQuery> {
  @override
  PatientsQuery build() => const PatientsQuery();

  void search(String text) =>
      state = PatientsQuery(text: text, filter: state.filter);

  void filterBy(PatientFilter filter) =>
      state = PatientsQuery(text: state.text, filter: filter);
}

final patientsQueryProvider =
    NotifierProvider.autoDispose<PatientsQueryController, PatientsQuery>(
      PatientsQueryController.new,
    );

/// Patients matching the search (name, village or ID) and filter, sorted by name.
List<PatientView> filterPatients(List<PatientView> all, PatientsQuery query) {
  final q = query.text.trim().toLowerCase();
  return all.where((v) {
    final matches =
        q.isEmpty ||
        v.patient.fullName.toLowerCase().contains(q) ||
        v.patient.village.toLowerCase().contains(q) ||
        v.patient.shortId.toLowerCase().contains(q);
    final ok = switch (query.filter) {
      PatientFilter.all => true,
      PatientFilter.followUp => v.status == StatusKind.followUp,
      PatientFilter.urgent => v.status == StatusKind.urgent,
    };
    return matches && ok;
  }).toList()..sort((a, b) => a.patient.fullName.compareTo(b.patient.fullName));
}

final visiblePatientsProvider = Provider.autoDispose<List<PatientView>>((ref) {
  final patients = ref.watch(allPatientsProvider).value ?? const [];
  final visits = ref.watch(allVisitsProvider).value ?? const [];
  return filterPatients(
    buildPatientViews(patients, visits),
    ref.watch(patientsQueryProvider),
  );
});

import 'package:drift/drift.dart' show Value;

import '../../data/db.dart' show Patient;
import '../repositories/patient_repository.dart';

/// Registers a new patient, or saves changes to [editing]. Cleans the form's raw text: trims names,
/// reads the age as whole years and treats an empty phone as none.
class SavePatient {
  SavePatient(this._patients);

  final PatientRepository _patients;

  Future<Patient> call({
    Patient? editing,
    required String fullName,
    required String village,
    String? sex,
    String age = '',
    String phone = '',
  }) {
    final ageEstimate = int.tryParse(age.trim());
    final phoneOrNull = phone.trim().isEmpty ? null : phone.trim();
    if (editing == null) {
      return _patients.create(
        fullName: fullName.trim(),
        village: village.trim(),
        sex: sex,
        ageEstimate: ageEstimate,
        phone: phoneOrNull,
      );
    }
    return _patients.update(
      editing.copyWith(
        fullName: fullName.trim(),
        village: village.trim(),
        sex: Value(sex),
        ageEstimate: Value(ageEstimate),
        phone: Value(phoneOrNull),
      ),
    );
  }
}

/// The app's "delete": the record and its visits are kept, and the archive can be undone.
class ArchivePatient {
  ArchivePatient(this._patients);

  final PatientRepository _patients;

  Future<Patient> call(Patient p) => _patients.archive(p);

  Future<Patient> undo(Patient p) => _patients.restore(p);
}

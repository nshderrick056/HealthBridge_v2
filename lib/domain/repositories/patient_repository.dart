// Patient and Visit are the immutable row classes drift generates (lib/data/db.dart); the domain uses
// them as its entities rather than duplicating every model and mapping between the two.
import '../../data/db.dart' show Patient;

/// What the app needs from patient storage. Implemented by the data layer's PatientsRepository,
/// which also queues every change for upload.
abstract interface class PatientRepository {
  Future<Patient> create({
    required String fullName,
    required String village,
    String? sex,
    DateTime? birthDate,
    int? ageEstimate,
    String? phone,
    DateTime? consentAt,
  });

  Future<Patient> update(Patient p);

  /// Hides the patient everywhere but keeps the record.
  Future<Patient> archive(Patient p);

  Future<Patient> restore(Patient p);

  Future<Patient?> get(String id);
}

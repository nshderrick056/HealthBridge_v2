import '../../data/db.dart' show Visit;
import '../entities/enums.dart';
import '../repositories/visit_repository.dart';

/// Records a reviewed visit. Empty notes are stored as none; whether the visit is urgent follows
/// from the danger signs, so the screen cannot get it wrong.
class RecordVisit {
  RecordVisit(this._visits);

  final VisitRepository _visits;

  Future<Visit> call({
    required String patientId,
    required VisitType type,
    required Map<String, Object?> answers,
    required Iterable<String> signCodes,
    String notes = '',
  }) => _visits.record(
    patientId: patientId,
    type: type,
    answers: answers,
    signCodes: signCodes.toList(),
    notes: notes.trim().isEmpty ? null : notes.trim(),
  );
}

import '../../data/db.dart' show Visit;
import '../entities/enums.dart';

/// What the app needs from visit storage. Implemented by the data layer's VisitsRepository, which
/// saves a visit, its danger signs and its upload queue entry together.
abstract interface class VisitRepository {
  /// Saves a finished visit. It is urgent exactly when [signCodes] is not empty.
  Future<Visit> record({
    required String patientId,
    required VisitType type,
    Map<String, Object?> answers,
    List<String> signCodes,
    String? notes,
    DateTime? followUpOn,
    DateTime? recordedAt,
  });

  Future<Visit?> get(String id);

  Future<List<String>> signCodes(String visitId);
}

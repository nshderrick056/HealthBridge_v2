import 'package:cloud_firestore/cloud_firestore.dart';

// The outbox keeps each change as the payload built when it was saved (patientPayload / visitPayload,
// snake_case JSON). These turn it into the Firestore document the security rules check, adding who owns
// it. Field names match docs/ERD.md and firestore.rules exactly.

Timestamp? _ts(Object? iso) =>
    iso == null ? null : Timestamp.fromDate(DateTime.parse(iso as String));

Map<String, Object?> firestorePatient(
  Map<String, dynamic> p, {
  required String chwId,
  required String healthCenterId,
}) => {
  'shortId': p['short_id'],
  'chwId': chwId,
  'healthCenterId': healthCenterId,
  'fullName': p['full_name'],
  'sex': p['sex'],
  'birthDate': _ts(p['birth_date']),
  'ageEstimate': p['age_estimate'],
  'village': p['village'],
  'phone': p['phone'],
  'consentAt': _ts(p['consent_at']),
  'createdAt': _ts(p['created_at']),
  'updatedAt': _ts(p['updated_at']),
  'archivedAt': _ts(p['archived_at']),
};

Map<String, Object?> firestoreVisit(
  Map<String, dynamic> v, {
  required String chwId,
  required String healthCenterId,
  required String deviceId,
}) => {
  'shortCode': v['short_code'],
  'patientId': v['patient_id'],
  'chwId': chwId,
  'healthCenterId': healthCenterId,
  'deviceId': deviceId,
  'type': v['type'],
  'answers': v['answers'] ?? const <String, Object?>{},
  'notes': v['notes'],
  'isUrgent': v['is_urgent'],
  'dangerSigns': v['danger_signs'] ?? const <String>[],
  'followUpOn': _ts(v['follow_up_on']),
  'recordedAt': _ts(v['recorded_at']),
  'receivedAt': FieldValue.serverTimestamp(),
  'source': 'app',
  'isPartial': false,
};

/// The internet alert for an urgent visit; its document ID is the visit's ID.
Map<String, Object?> firestoreAlert(
  String visitId, {
  required String chwId,
  required String healthCenterId,
}) => {
  'visitId': visitId,
  'chwId': chwId,
  'healthCenterId': healthCenterId,
  'channel': 'internet',
  'status': 'new',
  'createdAt': FieldValue.serverTimestamp(),
};

/// A Firestore time as UTC, or null.
DateTime? fromTimestamp(Object? v) =>
    v is Timestamp ? v.toDate().toUtc() : null;

import 'package:flutter_test/flutter_test.dart';
import 'package:health_bridge/domain/entities/supervision.dart';

void main() {
  test('a patient history reads the profile, CHW and visits from the API', () {
    final h = PatientHistory.fromJson({
      'patient': {
        'id': 'p1',
        'shortId': 'P0412',
        'name': 'Uwase Marie',
        'village': 'Nyamata',
        'sex': 'F',
        'ageEstimate': 32,
        'birthDate': null,
        'archived': false,
      },
      'chw': {'id': 'c1', 'name': 'Claudine M.', 'phone': '+250780000101'},
      'visits': [
        {
          'id': 'v1',
          'type': 'maternal',
          'recordedAt': '2026-11-10T08:00:00Z',
          'isUrgent': true,
          'isPartial': false,
          'dangerSigns': ['Heavy bleeding'],
          'temperature': 38.9,
          'condition': 'Needs attention',
          'symptoms': null,
          'notes': 'Referred',
          'followUpOn': null,
        },
      ],
    });
    expect(h.patient.name, 'Uwase Marie');
    expect(h.patient.ageSex, '32 years · Female');
    expect(h.patient.chwName, 'Claudine M.');
    expect(h.chwId, 'c1');
    expect(h.visits.single.isUrgent, isTrue);
    expect(h.visits.single.dangerSigns, ['Heavy bleeding']);
    expect(h.visits.single.temperature, 38.9);
  });

  test("a CHW's history links each visit to its patient", () {
    final h = ChwHistory.fromJson({
      'chw': {
        'id': 'c1',
        'name': 'Claudine M.',
        'chwRole': 'asm',
        'phone': '+250780000101',
        'village': 'Nyamata',
      },
      'visits': [
        {
          'id': 'v1',
          'type': 'child',
          'recordedAt': null,
          'isUrgent': false,
          'isPartial': true,
          'dangerSigns': [],
          'temperature': null,
          'condition': null,
          'symptoms': null,
          'notes': null,
          'followUpOn': null,
          'patient': {'id': 'p2', 'shortId': 'P0007', 'name': null},
        },
      ],
    });
    expect(h.chw.name, 'Claudine M.');
    expect(h.visits.single.patientId, 'p2');
    expect(h.visits.single.patientName, isNull);
    expect(h.visits.single.isPartial, isTrue);
  });
}

import '../../data/db.dart';
import '../../data/models.dart';

/// What the CHW has entered so far. Passed from the form to the review screen and autosaved as a draft.
class VisitForm {
  VisitForm({
    required this.patient,
    this.type = VisitType.maternal,
    this.symptoms = '',
    this.temperature,
    this.condition = 'Stable',
    this.notes = '',
    Set<String>? signs,
    this.followUpOn,
  }) : signs = signs ?? <String>{};

  final Patient patient;
  VisitType type;
  String symptoms;
  double? temperature;
  String condition;
  String notes;
  Set<String> signs;
  DateTime? followUpOn;

  Map<String, Object?> toDraft() => {
    'type': type.name,
    'symptoms': symptoms,
    'temperature': temperature,
    'condition': condition,
    'notes': notes,
    'signs': signs.toList(),
  };

  void restore(Map<String, Object?> d) {
    type = VisitType.values.asNameMap()[d['type']] ?? type;
    symptoms = d['symptoms'] as String? ?? '';
    temperature = (d['temperature'] as num?)?.toDouble();
    condition = d['condition'] as String? ?? 'Stable';
    notes = d['notes'] as String? ?? '';
    signs = {...((d['signs'] as List?)?.cast<String>() ?? const <String>[])};
  }

  Map<String, Object?> get answers => {
    'symptoms': symptoms,
    if (temperature != null) 'temperature': temperature,
    'general_condition': condition,
  };
}

// Entry validation (FR-05). The ranges are placeholders until the clinician sign-off and the Figma
// form fields are available (PRD 7); change them here, nowhere else.
class NumberRange {
  const NumberRange(this.min, this.max, this.unit);
  final double min;
  final double max;
  final String unit;

  bool contains(num v) => v >= min && v <= max;

  /// Null when [v] is valid, otherwise a message naming the allowed range.
  String? check(num? v) {
    if (v == null) return 'Required';
    return contains(v) ? null : 'Enter $min to $max $unit';
  }
}

const temperatureC = NumberRange(30, 45, '\u00B0C');
const muacMm = NumberRange(60, 250, 'mm');
const gestationalWeeks = NumberRange(1, 45, 'weeks');

import '../models.dart';

/// Any ticked danger sign makes the visit urgent (FR-06).
bool isUrgent(Iterable<String> signCodes) => signCodes.isNotEmpty;

typedef DangerSignSeed = ({
  String code,
  VisitType type,
  String labelEn,
  String labelRw,
});

/// PLACEHOLDER list, same codes as server/prisma/seed.ts. Codes and English labels are to be confirmed
/// from the Figma forms and a clinician; Kinyarwanda labels need a native speaker (left empty on purpose).
/// Refreshed from the server on sync.
const seedDangerSigns = <DangerSignSeed>[
  (
    code: 'HB',
    type: VisitType.maternal,
    labelEn: 'Heavy bleeding',
    labelRw: '',
  ),
  (code: 'CV', type: VisitType.maternal, labelEn: 'Convulsions', labelRw: ''),
  (
    code: 'SH',
    type: VisitType.maternal,
    labelEn: 'Severe headache or blurred vision',
    labelRw: '',
  ),
  (
    code: 'UD',
    type: VisitType.child,
    labelEn: 'Unable to drink or breastfeed',
    labelRw: '',
  ),
  (
    code: 'VE',
    type: VisitType.child,
    labelEn: 'Vomits everything',
    labelRw: '',
  ),
  (code: 'CC', type: VisitType.child, labelEn: 'Convulsions', labelRw: ''),
  (
    code: 'LT',
    type: VisitType.malaria,
    labelEn: 'Lethargic or unconscious',
    labelRw: '',
  ),
  (
    code: 'HF',
    type: VisitType.malaria,
    labelEn: 'Very high fever',
    labelRw: '',
  ),
  (code: 'MR', type: VisitType.nutrition, labelEn: 'MUAC red', labelRw: ''),
  (
    code: 'OE',
    type: VisitType.nutrition,
    labelEn: 'Swelling of both feet',
    labelRw: '',
  ),
];

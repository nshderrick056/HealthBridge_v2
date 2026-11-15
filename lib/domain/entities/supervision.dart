// What supervisors and admins see, as the HealthBridge API returns it (server/src/supervisor and admin).

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// Where a case is; the server decides which moves are allowed.
enum AlertStatus {
  newCase('new', 'New'),
  reviewed('reviewed', 'Reviewed'),
  escalated('escalated', 'Escalated'),
  followUp('follow_up', 'Follow-up'),
  resolved('resolved', 'Resolved');

  const AlertStatus(this.wire, this.label);
  final String wire;
  final String label;

  static AlertStatus parse(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => newCase);
}

class AlertSummary {
  AlertSummary.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      status = AlertStatus.parse(j['status'] as String),
      channel = j['channel'] as String,
      createdAt = _date(j['createdAt']),
      isPartial = j['isPartial'] as bool? ?? false,
      visitType = (j['visit'] as Map?)?['type'] as String?,
      patientShortId = (j['patient'] as Map?)?['shortId'] as String?,
      patientName = (j['patient'] as Map?)?['name'] as String?,
      chwName = (j['chw'] as Map?)?['name'] as String?,
      village = j['village'] as String?,
      dangerSigns = ((j['dangerSigns'] as List?) ?? const []).cast<String>();

  final String id;
  final AlertStatus status;

  /// internet | sms
  final String channel;
  final DateTime? createdAt;

  /// Reached the health centre by SMS only; the full visit has not arrived yet.
  final bool isPartial;
  final String? visitType;
  final String? patientShortId;

  /// Null while the case came by SMS only (the name is not in the SMS).
  final String? patientName;
  final String? chwName;
  final String? village;
  final List<String> dangerSigns;
}

class AlertEvent {
  AlertEvent.fromJson(Map<String, dynamic> j)
    : from = j['fromStatus'] == null
          ? null
          : AlertStatus.parse(j['fromStatus'] as String),
      to = AlertStatus.parse(j['toStatus'] as String),
      note = j['note'] as String?,
      actor = j['actor'] as String?,
      at = _date(j['createdAt']);

  final AlertStatus? from;
  final AlertStatus to;
  final String? note;
  final String? actor;
  final DateTime? at;
}

class AlertDetail {
  AlertDetail.fromJson(Map<String, dynamic> j)
    : summary = AlertSummary.fromJson({
        ...j,
        'isPartial': (j['visit'] as Map?)?['isPartial'],
        'dangerSigns': [
          for (final s in (j['dangerSigns'] as List? ?? const []))
            (s as Map)['label'],
        ],
        'village': (j['patient'] as Map?)?['village'],
      }),
      next = [
        for (final s in (j['next'] as List? ?? const []))
          AlertStatus.parse(s as String),
      ],
      shortCode = (j['visit'] as Map?)?['shortCode'] as String?,
      recordedAt = _date((j['visit'] as Map?)?['recordedAt']),
      notes = (j['visit'] as Map?)?['notes'] as String?,
      answers = Map<String, dynamic>.from(
        (j['visit'] as Map?)?['answers'] as Map? ?? const {},
      ),
      patientSex = (j['patient'] as Map?)?['sex'] as String?,
      patientAge = ((j['patient'] as Map?)?['ageEstimate'] as num?)?.toInt(),
      chwPhone = (j['chw'] as Map?)?['phone'] as String?,
      events = [
        for (final e in (j['events'] as List? ?? const []))
          AlertEvent.fromJson(e as Map<String, dynamic>),
      ];

  final AlertSummary summary;

  /// The statuses the case can move to now.
  final List<AlertStatus> next;
  final String? shortCode;
  final DateTime? recordedAt;
  final String? notes;
  final Map<String, dynamic> answers;
  final String? patientSex;
  final int? patientAge;
  final String? chwPhone;
  final List<AlertEvent> events;
}

class ChwSummary {
  ChwSummary.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      chwRole = j['chwRole'] as String?,
      phone = j['phone'] as String?,
      village = j['village'] as String?,
      lastSyncAt = _date(j['lastSyncAt']),
      pendingCount = (j['pendingCount'] as num?)?.toInt() ?? 0;

  final String id;
  final String name;
  final String? chwRole;
  final String? phone;
  final String? village;
  final DateTime? lastSyncAt;

  /// Urgent cases that reached the centre only by SMS and still wait for the full record.
  final int pendingCount;
}

class ResetRequest {
  ResetRequest.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String?,
      phone = j['phone'] as String?,
      role = j['role'] as String?,
      createdAt = _date(j['createdAt']);

  final String id;
  final String? name;
  final String? phone;
  final String? role;
  final DateTime? createdAt;
}

class HealthCentre {
  HealthCentre.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String;

  final String id;
  final String name;
}

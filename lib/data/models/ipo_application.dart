enum ApplicationStatus {
  waiting,
  checking,
  allotted,
  notAllotted,
  noRecord,
  resultNotLive,
  humanRequired,
  temporaryError,
  unsupportedRegistrar,
  unknown,
}

class IpoApplication {
  const IpoApplication({
    required this.id,
    required this.ipoId,
    required this.panProfileId,
    required this.addedAt,
    required this.status,
    this.lastCheckedAt,
    this.allottedShares,
    this.applicationNumber,
    this.lastMessage,
  });

  final String id;
  final String ipoId;
  final String panProfileId;
  final DateTime addedAt;
  final ApplicationStatus status;
  final DateTime? lastCheckedAt;
  final int? allottedShares;
  final String? applicationNumber;
  final String? lastMessage;

  bool get isCompleted =>
      status == ApplicationStatus.allotted ||
      status == ApplicationStatus.notAllotted;

  IpoApplication copyWith({
    String? id,
    String? ipoId,
    String? panProfileId,
    DateTime? addedAt,
    ApplicationStatus? status,
    DateTime? lastCheckedAt,
    int? allottedShares,
    String? applicationNumber,
    String? lastMessage,
    bool clearLastCheckedAt = false,
    bool clearAllottedShares = false,
    bool clearApplicationNumber = false,
    bool clearLastMessage = false,
  }) {
    return IpoApplication(
      id: id ?? this.id,
      ipoId: ipoId ?? this.ipoId,
      panProfileId: panProfileId ?? this.panProfileId,
      addedAt: addedAt ?? this.addedAt,
      status: status ?? this.status,
      lastCheckedAt: clearLastCheckedAt
          ? null
          : (lastCheckedAt ?? this.lastCheckedAt),
      allottedShares: clearAllottedShares
          ? null
          : (allottedShares ?? this.allottedShares),
      applicationNumber: clearApplicationNumber
          ? null
          : (applicationNumber ?? this.applicationNumber),
      lastMessage: clearLastMessage
          ? null
          : (lastMessage ?? this.lastMessage),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ipoId': ipoId,
        'panProfileId': panProfileId,
        'addedAt': addedAt.toIso8601String(),
        'status': status.name,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
        'allottedShares': allottedShares,
        'applicationNumber': applicationNumber,
        'lastMessage': lastMessage,
      };

  factory IpoApplication.fromJson(Map<String, dynamic> json) {
    final storedStatus =
        json['status'] as String? ?? ApplicationStatus.waiting.name;

    final statusName = storedStatus == 'error'
        ? ApplicationStatus.temporaryError.name
        : storedStatus;

    var status = ApplicationStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => ApplicationStatus.waiting,
    );

    // A transient request state must never survive process/app restarts.
    if (status == ApplicationStatus.checking) {
      status = ApplicationStatus.waiting;
    }

    int? intValue(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '');
    }

    DateTime? dateValue(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return IpoApplication(
      id: json['id'] as String,
      ipoId: json['ipoId'] as String,
      panProfileId: json['panProfileId'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      status: status,
      lastCheckedAt: dateValue(json['lastCheckedAt']),
      allottedShares: intValue(json['allottedShares']),
      applicationNumber: json['applicationNumber']?.toString(),
      lastMessage: json['lastMessage']?.toString(),
    );
  }
}

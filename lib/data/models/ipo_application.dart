enum ApplicationStatus {
  waiting,
  checking,
  allotted,
  notAllotted,
  resultNotLive,
  humanRequired,
  error,
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
  });

  final String id;
  final String ipoId;
  final String panProfileId;
  final DateTime addedAt;
  final ApplicationStatus status;
  final DateTime? lastCheckedAt;
  final int? allottedShares;

  bool get isCompleted =>
      status == ApplicationStatus.allotted ||
      status == ApplicationStatus.notAllotted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ipoId': ipoId,
        'panProfileId': panProfileId,
        'addedAt': addedAt.toIso8601String(),
        'status': status.name,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
        'allottedShares': allottedShares,
      };

  factory IpoApplication.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? ApplicationStatus.waiting.name;
    final status = ApplicationStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => ApplicationStatus.waiting,
    );

    return IpoApplication(
      id: json['id'] as String,
      ipoId: json['ipoId'] as String,
      panProfileId: json['panProfileId'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      status: status,
      lastCheckedAt: json['lastCheckedAt'] == null
          ? null
          : DateTime.tryParse(json['lastCheckedAt'] as String),
      allottedShares: json['allottedShares'] as int?,
    );
  }
}

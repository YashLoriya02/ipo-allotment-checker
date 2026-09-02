enum AllotmentApiStatus {
  allotted,
  notAllotted,
  noRecord,
  notLive,
  humanRequired,
  temporaryError,
  unsupportedRegistrar,
  unknown,
}

class AllotmentCheckResult {
  const AllotmentCheckResult({
    required this.status,
    required this.registrar,
    required this.ipoName,
    this.sharesAllotted,
    this.applicationNumber,
    this.message,
  });

  final AllotmentApiStatus status;
  final String registrar;
  final String ipoName;
  final int? sharesAllotted;
  final String? applicationNumber;
  final String? message;

  factory AllotmentCheckResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString().trim().toUpperCase();

    final status = switch (rawStatus) {
      'ALLOTTED' => AllotmentApiStatus.allotted,
      'NOT_ALLOTTED' => AllotmentApiStatus.notAllotted,
      'NO_RECORD' => AllotmentApiStatus.noRecord,
      'NOT_LIVE' => AllotmentApiStatus.notLive,
      'HUMAN_REQUIRED' => AllotmentApiStatus.humanRequired,
      'TEMPORARY_ERROR' => AllotmentApiStatus.temporaryError,
      'UNSUPPORTED_REGISTRAR' => AllotmentApiStatus.unsupportedRegistrar,
      _ => AllotmentApiStatus.unknown,
    };

    int? intValue(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '');
    }

    String? stringValue(dynamic raw) {
      final value = raw?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return AllotmentCheckResult(
      status: status,
      registrar: stringValue(json['registrar']) ?? '',
      ipoName: stringValue(json['ipoName']) ?? '',
      sharesAllotted: intValue(json['sharesAllotted']),
      applicationNumber: stringValue(json['applicationNumber']),
      message: stringValue(json['message']),
    );
  }
}

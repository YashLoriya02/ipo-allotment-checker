import 'package:get/get.dart';

import '../models/allotment_check_result.dart';
import '../models/ipo.dart';
import '../registrars/kfin_client_id_registry.dart';

class KfinAllotmentService extends GetxService {
  static const String _queryUrl =
      'https://0uz601ms56.execute-api.ap-south-1.amazonaws.com/prod/api/query?type=pan';

  final GetConnect _client = GetConnect(timeout: const Duration(seconds: 25));

  bool supportsRegistrar(Ipo ipo) {
    final registrar = (ipo.registrarCode ?? ipo.registrarName ?? '')
        .trim()
        .toUpperCase();

    return registrar.contains('KFIN') || registrar.contains('K FINTECH');
  }

  String? clientIdFor(Ipo ipo) => KfinClientIdRegistry.resolve(ipo);

  Future<AllotmentCheckResult> checkAllotment({
    required Ipo ipo,
    required String pan,
    bool skipAllotmentDateGuard = false,
  }) async {
    if (!supportsRegistrar(ipo)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unsupportedRegistrar,
        message: 'This registrar is not supported yet.',
      );
    }

    if (!skipAllotmentDateGuard && _isBeforeAllotmentDate(ipo.allotmentDate)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.notLive,
        message: 'The allotment result is not available yet.',
      );
    }

    final clientId = clientIdFor(ipo);
    if (clientId == null) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unknown,
        message: 'KFin client ID is not configured for this IPO yet.',
      );
    }

    final normalizedPan = pan.trim().toUpperCase();

    final response = await _client.get(
      _queryUrl,
      headers: <String, String>{
        'Accept': 'application/json, text/plain, */*',
        'client_id': clientId,
        'reqparam': normalizedPan,
        'Origin': 'https://ipostatus.kfintech.com',
        'Referer': 'https://ipostatus.kfintech.com/',
      },
    );

    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode == 404 && _isRecordNotFound(body)) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.noRecord,
        message: 'No allotment record was found for this PAN and IPO.',
      );
    }

    if (!response.isOk) {
      throw KfinAllotmentException(
        _extractError(body) ??
            'KFin check failed (${statusCode ?? 'network error'}).',
        statusCode: statusCode,
      );
    }

    if (body is! Map) {
      throw const KfinAllotmentException('KFin returned an invalid response.');
    }

    final payload = Map<String, dynamic>.from(body);
    final rawData = payload['data'];

    if (rawData is! List || rawData.isEmpty) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.noRecord,
        message: 'No allotment record was found for this PAN and IPO.',
      );
    }

    final rawRecord = rawData.first;
    if (rawRecord is! Map) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unknown,
        message: 'KFin returned an unexpected result format.',
      );
    }

    final record = Map<String, dynamic>.from(rawRecord);
    final allottedShares = _intValue(record['All_Shares']);
    final appliedShares = _intValue(record['App_Shares']);
    final applicationNumber = _stringValue(record['Appln_No']);

    if (allottedShares == null) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.unknown,
        applicationNumber: applicationNumber,
        message: 'Could not determine the allotment status from KFin.',
      );
    }

    if (allottedShares > 0) {
      return _result(
        ipo: ipo,
        status: AllotmentApiStatus.allotted,
        sharesAllotted: allottedShares,
        applicationNumber: applicationNumber,
        message: '$allottedShares shares allotted.',
      );
    }

    return _result(
      ipo: ipo,
      status: AllotmentApiStatus.notAllotted,
      sharesAllotted: 0,
      applicationNumber: applicationNumber,
      message: appliedShares == null
          ? 'No shares were allotted.'
          : 'Applied for $appliedShares shares. No shares were allotted.',
    );
  }

  AllotmentCheckResult _result({
    required Ipo ipo,
    required AllotmentApiStatus status,
    int? sharesAllotted,
    String? applicationNumber,
    String? message,
  }) {
    return AllotmentCheckResult(
      status: status,
      registrar: 'KFIN',
      ipoName: ipo.name,
      sharesAllotted: sharesAllotted,
      applicationNumber: applicationNumber,
      message: message,
    );
  }

  bool _isBeforeAllotmentDate(DateTime? value) {
    if (value == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allotmentDate = DateTime(value.year, value.month, value.day);
    return today.isBefore(allotmentDate);
  }

  bool _isRecordNotFound(dynamic body) {
    final error = _extractError(body)?.toLowerCase();
    return error == 'record not found' ||
        (error?.contains('record not found') ?? false);
  }

  String? _extractError(dynamic body) {
    if (body is Map) {
      final value = body['error']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    if (body is String) {
      final value = body.trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  int? _intValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString().trim() ?? '');
  }

  String? _stringValue(dynamic raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class KfinAllotmentException implements Exception {
  const KfinAllotmentException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

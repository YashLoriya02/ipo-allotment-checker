import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../models/allotment_check_result.dart';

class AllotmentApiService extends GetxService {
  final GetConnect _client = GetConnect(timeout: const Duration(seconds: 45));

  bool get isConfigured => AppConfig.hasAllotmentApi;

  Future<AllotmentCheckResult> checkAllotment({
    required String ipoId,
    required String ipoName,
    required String registrar,
    required String pan,
  }) async {
    if (!isConfigured) {
      throw const AllotmentApiException(
        'Allotment backend is not configured. Set ALLOTMENT_API_BASE_URL when running the app.',
      );
    }

    debugPrint(
      {
        'ipoId': ipoId,
        'ipoName': "$ipoName IPO".replaceAll("&", "and").toUpperCase(),
        'registrar': registrar,
        'pan': pan,
      }.toString(),
    );

    final response = await _client.post(
      '${AppConfig.normalizedAllotmentApiBaseUrl}/v1/allotment/check',
      <String, dynamic>{
        'ipoId': ipoId,
        'ipoName': ipoName,
        'registrar': registrar,
        'pan': pan,
      },
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    final body = response.body;

    if (!response.isOk) {
      throw AllotmentApiException(
        _extractMessage(body) ??
            'Allotment check failed (${response.statusCode ?? 'network error'}).',
        statusCode: response.statusCode,
      );
    }

    if (body is! Map) {
      throw const AllotmentApiException(
        'Allotment backend returned an invalid response.',
      );
    }

    return AllotmentCheckResult.fromJson(Map<String, dynamic>.from(body));
  }

  String? _extractMessage(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    final direct = map['message']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final detail = map['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    return null;
  }
}

class AllotmentApiException implements Exception {
  const AllotmentApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

import 'package:app/core/constants/constants.dart';

abstract class AppConfig {
  static const String allotmentApiBaseUrl = ALLOTMENT_API_BASE_URL;

  static bool get hasAllotmentApi => allotmentApiBaseUrl.trim().isNotEmpty;

  static String get normalizedAllotmentApiBaseUrl {
    final value = allotmentApiBaseUrl.trim();
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

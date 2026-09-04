import 'package:ipo_allotment_tracker/core/constants/constants.dart';

abstract class AppConfig {
  static const String allotmentApiBaseUrl = ALLOTMENT_API_BASE_URL;
  static const bool autoAllotmentChecksEnabled = ALLOTMENT_AUTO_CHECKS;
  static const bool backgroundTestMode = ALLOTMENT_BG_TEST;

  static bool get hasAllotmentApi => allotmentApiBaseUrl.trim().isNotEmpty;

  static String get normalizedAllotmentApiBaseUrl {
    final value = allotmentApiBaseUrl.trim();
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/ipo.dart';
import '../models/ipo_application.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize({bool requestPermission = true}) async {
    if (!_initialized) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      final darwinSettings = const DarwinInitializationSettings();

      final settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(settings);
      _initialized = true;
    }

    if (requestPermission && !_permissionRequested) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _permissionRequested = true;
    }
  }

  Future<void> showAllotmentResult({
    required Ipo ipo,
    required IpoApplication application,
    String? profileName,
    bool automatic = false,
    bool requestPermission = true,
  }) async {
    await initialize(requestPermission: requestPermission);

    final label = ipo.symbol.trim().isEmpty ? ipo.name : ipo.symbol;

    final (baseTitle, body) = _content(
      label,
      application,
      profileName: profileName,
    );

    final title = baseTitle;

    const androidDetails = AndroidNotificationDetails(
      'ipo_allotment_results',
      'IPO Allotment Results',
      channelDescription: 'IPO allotment status results.',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    final notificationDetails = const NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      application.id.hashCode & 0x7fffffff,
      title,
      body,
      notificationDetails,
      payload: application.id,
    );
  }

  /// Backward-compatible name used by any older call sites.
  Future<void> showManualCheckResult({
    required Ipo ipo,
    required IpoApplication application,
  }) {
    return showAllotmentResult(ipo: ipo, application: application);
  }

  /// Debug-only helper used by the Profile developer tool. This posts a real
  /// Android notification from this application, allowing the notification
  /// listener to be tested end-to-end on an emulator.
  Future<void> showDebugTriggerNotification({
    required String title,
    required String message,
  }) async {
    assert(() {
      return true;
    }());

    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'ipo_trigger_debug',
      'IPO Trigger Debug',
      channelDescription:
          'Debug notifications used to test IPO trigger detection.',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      title.trim(),
      message.trim(),
      details,
    );
  }

  (String, String) _content(
    String label,
    IpoApplication application, {
    String? profileName,
  }) {
    final person = profileName?.trim();

    final applicationLabel = person != null && person.isNotEmpty
        ? '$label · $person'
        : label;

    return switch (application.status) {
      ApplicationStatus.allotted => (
        'Allotted 🎉',
        application.allottedShares == null
            ? '$applicationLabel allotment found.'
            : '$applicationLabel\n'
                  '${application.allottedShares} shares allotted.',
      ),

      ApplicationStatus.notAllotted => (
        'Not allotted',
        '$applicationLabel\nNo shares were allotted.',
      ),

      ApplicationStatus.noRecord => (
        'No allotment record',
        '$applicationLabel\nNo record found for this application.',
      ),

      ApplicationStatus.resultNotLive => (
        'Result not live yet',
        '$applicationLabel\nAllotment result is not available yet.',
      ),

      ApplicationStatus.unsupportedRegistrar => (
        'Registrar not supported',
        '$applicationLabel\n'
            '${application.lastMessage ?? 'Cannot be checked yet.'}',
      ),

      ApplicationStatus.unknown => (
        'Allotment check incomplete',
        '$applicationLabel\n'
            '${application.lastMessage ?? 'Result could not be interpreted.'}',
      ),

      ApplicationStatus.temporaryError => (
        'Allotment check failed',
        '$applicationLabel\n'
            '${application.lastMessage ?? 'Could not be checked right now.'}',
      ),

      ApplicationStatus.humanRequired => (
        'Verification required',
        '$applicationLabel\nManual verification is required.',
      ),

      ApplicationStatus.waiting || ApplicationStatus.checking => (
        'IPO allotment',
        '$applicationLabel\nAllotment check is still pending.',
      ),
    };
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/ipo.dart';
import '../models/ipo_application.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final darwinSettings = const DarwinInitializationSettings();

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showManualCheckResult({
    required Ipo ipo,
    required IpoApplication application,
  }) async {
    await initialize();

    final label = ipo.symbol.trim().isEmpty ? ipo.name : ipo.symbol;
    final (title, body) = _content(label, application);

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

  (String, String) _content(String label, IpoApplication application) {
    return switch (application.status) {
      ApplicationStatus.allotted => (
        'Allotted 🎉',
        application.allottedShares == null
            ? '$label allotment found.'
            : '$label: ${application.allottedShares} shares allotted.',
      ),
      ApplicationStatus.notAllotted => (
        'Not allotted',
        '$label: no shares were allotted.',
      ),
      ApplicationStatus.noRecord => (
        'No allotment record',
        '$label: no record found for this PAN.',
      ),
      ApplicationStatus.resultNotLive => (
        'Result not live yet',
        '$label allotment result is not available yet.',
      ),
      ApplicationStatus.unsupportedRegistrar => (
        'Registrar not supported',
        application.lastMessage ?? '$label cannot be checked yet.',
      ),
      ApplicationStatus.unknown => (
        'Allotment check incomplete',
        application.lastMessage ?? '$label result could not be interpreted.',
      ),
      ApplicationStatus.temporaryError => (
        'Allotment check failed',
        application.lastMessage ?? '$label could not be checked right now.',
      ),
      ApplicationStatus.humanRequired => (
        'Verification required',
        '$label requires manual verification.',
      ),
      ApplicationStatus.waiting || ApplicationStatus.checking => (
        'IPO allotment',
        '$label allotment check is still pending.',
      ),
    };
  }
}

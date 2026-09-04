import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'app/app.dart';
import 'data/services/ipo_premium_notification_listener_service.dart';
import 'data/services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init('ipo_tracker');
  await LocalNotificationService.instance.initialize();
  await IpoPremiumNotificationListenerService.instance.initialize();
  runApp(const IpoTrackerApp());
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/profile/controllers/theme_controller.dart';

class IpoTrackerApp extends StatelessWidget {
  const IpoTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'IPO Tracker',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.shell,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 260),
      builder: (context, child) {
        final themeController = Get.find<ThemeController>();
        return Obx(() {
          final mode = themeController.themeMode.value;
          final brightness = mode == ThemeMode.dark
              ? Brightness.dark
              : mode == ThemeMode.light
                  ? Brightness.light
                  : MediaQuery.platformBrightnessOf(context);
          return Theme(
            data: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
            child: child ?? const SizedBox.shrink(),
          );
        });
      },
    );
  }
}

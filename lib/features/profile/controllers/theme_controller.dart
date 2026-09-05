import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/local_storage_service.dart';

class ThemeController extends GetxController {
  ThemeController() : _storage = Get.find<LocalStorageService>();

  final LocalStorageService _storage;
  final themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    reloadFromStorage();
  }

  void reloadFromStorage() {
    final stored = _storage.readThemeMode();
    themeMode.value = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    Get.changeThemeMode(themeMode.value);
  }

  Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _storage.writeThemeMode(mode.name);
  }

  bool get isDark {
    if (themeMode.value == ThemeMode.dark) return true;
    if (themeMode.value == ThemeMode.light) return false;
    return Get.isPlatformDarkMode;
  }
}

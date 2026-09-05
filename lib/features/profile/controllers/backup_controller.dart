import 'dart:ui';

import 'package:get/get.dart';

import '../../../data/models/app_backup.dart';
import '../../../data/services/data_backup_service.dart';
import '../../applied/controllers/applied_controller.dart';
import '../../discover/controllers/discover_controller.dart';
import 'profile_controller.dart';
import 'theme_controller.dart';

class BackupController extends GetxController {
  BackupController()
    : _backupService = Get.find<DataBackupService>(),
      _profileController = Get.find<ProfileController>(),
      _appliedController = Get.find<AppliedController>(),
      _discoverController = Get.find<DiscoverController>(),
      _themeController = Get.find<ThemeController>();

  final DataBackupService _backupService;
  final ProfileController _profileController;
  final AppliedController _appliedController;
  final DiscoverController _discoverController;
  final ThemeController _themeController;

  final isExporting = false.obs;
  final isImporting = false.obs;

  Future<void> exportBackup({Rect? sharePositionOrigin}) async {
    if (isExporting.value || isImporting.value) return;
    isExporting.value = true;
    try {
      await _backupService.shareBackup(
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (error) {
      Get.snackbar(
        'Could not export backup',
        _messageFor(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isExporting.value = false;
    }
  }

  Future<AppBackup?> pickBackup() async {
    if (isExporting.value || isImporting.value) return null;
    isImporting.value = true;
    try {
      return await _backupService.pickBackup();
    } catch (error) {
      Get.snackbar(
        'Could not read backup',
        _messageFor(error),
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isImporting.value = false;
    }
  }

  Future<bool> restoreBackup(AppBackup backup) async {
    if (isExporting.value || isImporting.value) return false;
    isImporting.value = true;
    try {
      await _backupService.restoreBackup(backup);
      _profileController.reloadFromStorage();
      _appliedController.reloadApplicationsFromStorage();
      _discoverController.reloadFromStorage();
      _themeController.reloadFromStorage();

      Get.snackbar(
        'Backup restored',
        '${backup.profiles.length} PAN profiles and '
            '${backup.applications.length} applications were restored.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (error) {
      Get.snackbar(
        'Could not restore backup',
        _messageFor(error),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isImporting.value = false;
    }
  }

  String _messageFor(Object error) => switch (error) {
    BackupFormatException() => error.message,
    BackupOperationException() => error.message,
    _ => 'Something went wrong. Please try again.',
  };
}

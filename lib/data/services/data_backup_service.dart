import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_backup.dart';
import 'local_storage_service.dart';
import 'secure_storage_service.dart';

class DataBackupService extends GetxService {
  DataBackupService()
    : _storage = Get.find<LocalStorageService>(),
      _secureStorage = Get.find<SecureStorageService>();

  static const _maximumBackupBytes = 10 * 1024 * 1024;

  final LocalStorageService _storage;
  final SecureStorageService _secureStorage;
  final AppBackupCodec _codec = const AppBackupCodec();

  Future<AppBackup> createBackup() => _readCurrentData(requireEveryPan: true);

  Future<void> shareBackup({Rect? sharePositionOrigin}) async {
    final backup = await createBackup();
    final contents = _codec.encode(backup);
    final filename = _backupFilename(backup.exportedAt.toLocal());

    await SharePlus.instance.share(
      ShareParams(
        title: 'IPO Allotment Tracker backup',
        subject: 'IPO Allotment Tracker backup',
        text: 'Keep this file private. It contains unencrypted PAN numbers.',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(contents)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [filename],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<AppBackup?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;

    final selected = result.files.single;
    if (selected.size > _maximumBackupBytes) {
      throw const BackupOperationException(
        'The selected backup is larger than 10 MB.',
      );
    }

    final bytes = selected.bytes ?? await result.xFiles.single.readAsBytes();
    if (bytes.isEmpty) {
      throw const BackupOperationException('The selected backup is empty.');
    }

    try {
      return _codec.decode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException(
        'The backup file is not valid UTF-8 JSON.',
      );
    }
  }

  Future<void> restoreBackup(AppBackup backup) async {
    final previous = await _readCurrentData(requireEveryPan: false);
    final affectedProfileIds = <String>{
      ...previous.profiles.map((profile) => profile.id),
      ...backup.profiles.map((profile) => profile.id),
    };

    try {
      await _replaceSecurePans(
        affectedProfileIds: affectedProfileIds,
        pansByProfileId: backup.pansByProfileId,
      );
      await _writeLocalData(backup);
    } catch (_) {
      try {
        await _replaceSecurePans(
          affectedProfileIds: affectedProfileIds,
          pansByProfileId: previous.pansByProfileId,
        );
        await _writeLocalData(previous);
      } catch (_) {
        throw const BackupOperationException(
          'Restore failed and the previous data could not be fully recovered.',
        );
      }
      throw const BackupOperationException(
        'Restore failed. Your existing data was left unchanged.',
      );
    }
  }

  Future<AppBackup> _readCurrentData({required bool requireEveryPan}) async {
    final profiles = _storage.readProfiles();
    final pans = <String, String>{};
    for (final profile in profiles) {
      final pan = await _secureStorage.readPan(profile.id);
      if (pan == null || pan.trim().isEmpty) {
        if (requireEveryPan) {
          throw BackupOperationException(
            'The PAN for ${profile.name} is missing from secure storage.',
          );
        }
        continue;
      }
      pans[profile.id] = pan.toUpperCase().trim();
    }

    return AppBackup(
      exportedAt: DateTime.now().toUtc(),
      profiles: profiles,
      pansByProfileId: pans,
      applications: _storage.readApplications(),
      cachedIpos: _storage.readCachedIpos(),
      themeMode: _storage.readThemeMode(),
      discoverIpoType: _storage.readDiscoverIpoType(),
      lastIpoRefresh: _storage.readLastIpoRefresh(),
      processedNotificationTriggers: _storage
          .readProcessedNotificationTriggers(),
    );
  }

  Future<void> _replaceSecurePans({
    required Set<String> affectedProfileIds,
    required Map<String, String> pansByProfileId,
  }) async {
    for (final profileId in affectedProfileIds) {
      final pan = pansByProfileId[profileId];
      if (pan == null) {
        await _secureStorage.deletePan(profileId);
      } else {
        await _secureStorage.savePan(profileId, pan);
      }
    }
  }

  Future<void> _writeLocalData(AppBackup backup) async {
    await _storage.writeProfiles(backup.profiles);
    await _storage.writeApplications(backup.applications);
    await _storage.writeCachedIpos(backup.cachedIpos);
    await _storage.writeThemeMode(backup.themeMode);
    await _storage.writeDiscoverIpoType(backup.discoverIpoType);
    await _storage.writeLastIpoRefresh(backup.lastIpoRefresh);
    await _storage.writeProcessedNotificationTriggers(
      backup.processedNotificationTriggers,
    );
  }

  String _backupFilename(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return 'ipo-tracker-backup-${value.year}${twoDigits(value.month)}'
        '${twoDigits(value.day)}-${twoDigits(value.hour)}'
        '${twoDigits(value.minute)}.json';
  }
}

class BackupOperationException implements Exception {
  const BackupOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

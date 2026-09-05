import 'dart:convert';

import 'ipo.dart';
import 'ipo_application.dart';
import 'pan_profile.dart';

class AppBackup {
  const AppBackup({
    required this.exportedAt,
    required this.profiles,
    required this.pansByProfileId,
    required this.applications,
    required this.cachedIpos,
    required this.themeMode,
    required this.discoverIpoType,
    required this.lastIpoRefresh,
    required this.processedNotificationTriggers,
  });

  static const backupType = 'ipo_allotment_tracker_backup';
  static const schemaVersion = 1;

  final DateTime exportedAt;
  final List<PanProfile> profiles;
  final Map<String, String> pansByProfileId;
  final List<IpoApplication> applications;
  final List<Ipo> cachedIpos;
  final String? themeMode;
  final String? discoverIpoType;
  final DateTime? lastIpoRefresh;
  final Map<String, String> processedNotificationTriggers;

  Map<String, dynamic> toJson() => {
    'backupType': backupType,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'containsPlaintextPan': true,
    'data': {
      'panProfiles': profiles
          .map(
            (profile) => {
              ...profile.toJson(),
              'pan': pansByProfileId[profile.id],
            },
          )
          .toList(),
      'applications': applications.map((item) => item.toJson()).toList(),
      'cachedIpos': cachedIpos.map((item) => item.toJson()).toList(),
      'preferences': {
        'themeMode': themeMode,
        'discoverIpoType': discoverIpoType,
        'lastIpoRefresh': lastIpoRefresh?.toUtc().toIso8601String(),
      },
      'processedNotificationTriggers': processedNotificationTriggers,
    },
  };
}

class AppBackupCodec {
  const AppBackupCodec();

  String encode(AppBackup backup) =>
      const JsonEncoder.withIndent('  ').convert(backup.toJson());

  AppBackup decode(String source) {
    try {
      final decoded = jsonDecode(source);
      final root = _asMap(decoded, 'Backup root');

      if (root['backupType'] != AppBackup.backupType) {
        throw const BackupFormatException(
          'This file is not an IPO Allotment Tracker backup.',
        );
      }

      final version = root['schemaVersion'];
      if (version is! int) {
        throw const BackupFormatException('Backup version is missing.');
      }
      if (version > AppBackup.schemaVersion) {
        throw const BackupFormatException(
          'This backup was created by a newer app version.',
        );
      }
      if (version < 1) {
        throw const BackupFormatException('Backup version is not supported.');
      }

      final exportedAt = _date(root['exportedAt'], 'exportedAt');
      final data = _asMap(root['data'], 'data');
      final profileMaps = _asList(data['panProfiles'], 'panProfiles');

      final profiles = <PanProfile>[];
      final pans = <String, String>{};
      final profileIds = <String>{};

      for (var index = 0; index < profileMaps.length; index++) {
        final item = _asMap(profileMaps[index], 'panProfiles[$index]');
        final id = _nonEmptyString(item['id'], 'panProfiles[$index].id');
        if (!profileIds.add(id)) {
          throw BackupFormatException('Duplicate PAN profile ID: $id.');
        }

        final name = _nonEmptyString(item['name'], 'panProfiles[$index].name');
        final pan = _nonEmptyString(
          item['pan'],
          'panProfiles[$index].pan',
        ).toUpperCase().trim();
        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
          throw BackupFormatException(
            'PAN profile "${_safeLabel(name)}" contains an invalid PAN.',
          );
        }

        final isDefault = item['isDefault'];
        if (isDefault is! bool) {
          throw BackupFormatException(
            'panProfiles[$index].isDefault must be true or false.',
          );
        }

        profiles.add(
          PanProfile(
            id: id,
            name: name,
            maskedPan: _maskPan(pan),
            isDefault: isDefault,
          ),
        );
        pans[id] = pan;
      }

      _normalizeDefaultProfile(profiles);

      final applicationMaps = _asList(data['applications'], 'applications');
      final applications = <IpoApplication>[];
      final applicationIds = <String>{};
      for (var index = 0; index < applicationMaps.length; index++) {
        final item = _asMap(applicationMaps[index], 'applications[$index]');
        final id = _nonEmptyString(item['id'], 'applications[$index].id');
        _nonEmptyString(item['ipoId'], 'applications[$index].ipoId');
        _nonEmptyString(
          item['panProfileId'],
          'applications[$index].panProfileId',
        );
        _date(item['addedAt'], 'applications[$index].addedAt');
        if (!applicationIds.add(id)) {
          throw BackupFormatException('Duplicate application ID: $id.');
        }
        applications.add(IpoApplication.fromJson(item));
      }

      final ipoMaps = _asList(data['cachedIpos'], 'cachedIpos');
      final cachedIpos = <Ipo>[];
      final ipoIds = <String>{};
      for (var index = 0; index < ipoMaps.length; index++) {
        final item = _asMap(ipoMaps[index], 'cachedIpos[$index]');
        final ipo = Ipo.fromJson(item);
        if (ipo.id.isEmpty) {
          throw BackupFormatException('cachedIpos[$index].id is missing.');
        }
        if (!ipoIds.add(ipo.id)) {
          throw BackupFormatException('Duplicate cached IPO ID: ${ipo.id}.');
        }
        cachedIpos.add(ipo);
      }

      final preferences = _asMap(data['preferences'], 'preferences');
      final themeMode = _nullableString(
        preferences['themeMode'],
        'preferences.themeMode',
      );
      if (themeMode != null &&
          !const {'system', 'light', 'dark'}.contains(themeMode)) {
        throw const BackupFormatException(
          'Backup theme preference is invalid.',
        );
      }

      final discoverIpoType = _nullableString(
        preferences['discoverIpoType'],
        'preferences.discoverIpoType',
      );
      if (discoverIpoType != null &&
          !const {'mainboard', 'sme'}.contains(discoverIpoType)) {
        throw const BackupFormatException(
          'Backup IPO type preference is invalid.',
        );
      }

      final lastRefreshRaw = preferences['lastIpoRefresh'];
      final lastIpoRefresh = lastRefreshRaw == null
          ? null
          : _date(lastRefreshRaw, 'preferences.lastIpoRefresh');

      final triggerMap = _asMap(
        data['processedNotificationTriggers'] ?? <String, dynamic>{},
        'processedNotificationTriggers',
      );
      final processedTriggers = <String, String>{};
      for (final entry in triggerMap.entries) {
        if (entry.key.trim().isEmpty || entry.value is! String) {
          throw const BackupFormatException(
            'Notification trigger history is invalid.',
          );
        }
        _date(entry.value, 'processedNotificationTriggers.${entry.key}');
        processedTriggers[entry.key] = entry.value as String;
      }

      return AppBackup(
        exportedAt: exportedAt,
        profiles: profiles,
        pansByProfileId: pans,
        applications: applications,
        cachedIpos: cachedIpos,
        themeMode: themeMode,
        discoverIpoType: discoverIpoType,
        lastIpoRefresh: lastIpoRefresh,
        processedNotificationTriggers: processedTriggers,
      );
    } on BackupFormatException {
      rethrow;
    } on FormatException {
      throw const BackupFormatException(
        'The selected file is not valid JSON backup data.',
      );
    } catch (_) {
      throw const BackupFormatException(
        'The backup is incomplete or contains invalid data.',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic value, String field) {
    if (value is! Map) {
      throw BackupFormatException('$field must be a JSON object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _asList(dynamic value, String field) {
    if (value is! List) {
      throw BackupFormatException('$field must be a JSON list.');
    }
    return value;
  }

  static String _nonEmptyString(dynamic value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw BackupFormatException('$field is missing.');
    }
    return value.trim();
  }

  static String? _nullableString(dynamic value, String field) {
    if (value == null) return null;
    if (value is! String) {
      throw BackupFormatException('$field must be text or null.');
    }
    return value;
  }

  static DateTime _date(dynamic value, String field) {
    if (value is! String) {
      throw BackupFormatException('$field must be a date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw BackupFormatException('$field contains an invalid date.');
    }
    return parsed;
  }

  static String _maskPan(String pan) =>
      '${'*' * (pan.length - 5)}${pan.substring(pan.length - 5)}';

  static String _safeLabel(String value) =>
      value.length <= 40 ? value : '${value.substring(0, 40)}...';

  static void _normalizeDefaultProfile(List<PanProfile> profiles) {
    if (profiles.isEmpty) return;
    var foundDefault = false;
    for (var index = 0; index < profiles.length; index++) {
      final shouldBeDefault = profiles[index].isDefault && !foundDefault;
      foundDefault = foundDefault || shouldBeDefault;
      profiles[index] = profiles[index].copyWith(isDefault: shouldBeDefault);
    }
    if (!foundDefault) {
      profiles[0] = profiles[0].copyWith(isDefault: true);
    }
  }
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

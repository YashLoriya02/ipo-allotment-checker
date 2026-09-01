import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/storage_keys.dart';
import '../models/ipo_application.dart';
import '../models/pan_profile.dart';

class LocalStorageService extends GetxService {
  final GetStorage _box = GetStorage('ipo_tracker');

  List<IpoApplication> readApplications() {
    final raw =
        _box.read<List<dynamic>>(StorageKeys.applications) ?? <dynamic>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => IpoApplication.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> writeApplications(List<IpoApplication> items) {
    return _box.write(
      StorageKeys.applications,
      items.map((item) => item.toJson()).toList(),
    );
  }

  List<PanProfile> readProfiles() {
    final raw =
        _box.read<List<dynamic>>(StorageKeys.panProfiles) ?? <dynamic>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => PanProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> writeProfiles(List<PanProfile> items) {
    return _box.write(
      StorageKeys.panProfiles,
      items.map((item) => item.toJson()).toList(),
    );
  }

  String? readThemeMode() => _box.read<String>(StorageKeys.themeMode);

  Future<void> writeThemeMode(String value) {
    return _box.write(StorageKeys.themeMode, value);
  }

  String? readDiscoverIpoType() =>
      _box.read<String>(StorageKeys.discoverIpoType);

  Future<void> writeDiscoverIpoType(String? value) {
    if (value == null) {
      return _box.remove(StorageKeys.discoverIpoType);
    }
    return _box.write(StorageKeys.discoverIpoType, value);
  }
}

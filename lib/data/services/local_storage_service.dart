import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/storage_keys.dart';
import '../models/ipo.dart';
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

  List<Ipo> readCachedIpos() {
    final raw = _box.read<List<dynamic>>(StorageKeys.cachedIpos) ?? <dynamic>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Ipo.fromJson(Map<String, dynamic>.from(item)))
        .where((ipo) => ipo.id.isNotEmpty)
        .toList();
  }

  Ipo? readCachedIpoById(String id) {
    for (final ipo in readCachedIpos()) {
      if (ipo.id == id) return ipo;
    }
    return null;
  }

  Future<void> writeCachedIpos(List<Ipo> items) {
    return _box.write(
      StorageKeys.cachedIpos,
      items.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> upsertCachedIpo(Ipo ipo) async {
    final items = readCachedIpos();
    final index = items.indexWhere((item) => item.id == ipo.id);
    if (index == -1) {
      items.add(ipo);
    } else {
      // Keep fresh lifecycle/basic data while adding richer details.
      items[index] = items[index].mergeDetailsFrom(ipo);
    }
    await writeCachedIpos(items);
  }

  DateTime? readLastIpoRefresh() {
    final raw = _box.read<String>(StorageKeys.lastIpoRefresh);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> writeLastIpoRefresh(DateTime value) {
    return _box.write(StorageKeys.lastIpoRefresh, value.toIso8601String());
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

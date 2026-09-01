import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/pan_profile.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/secure_storage_service.dart';
import '../widgets/add_pan_sheet.dart';

class ProfileController extends GetxController {
  ProfileController()
      : _storage = Get.find<LocalStorageService>(),
        _secureStorage = Get.find<SecureStorageService>();

  final LocalStorageService _storage;
  final SecureStorageService _secureStorage;

  final profiles = <PanProfile>[].obs;

  @override
  void onInit() {
    super.onInit();
    profiles.assignAll(_storage.readProfiles());
  }

  PanProfile? get defaultProfile {
    if (profiles.isEmpty) return null;
    return profiles.firstWhereOrNull((profile) => profile.isDefault) ?? profiles.first;
  }

  void openAddProfileSheet() {
    FocusManager.instance.primaryFocus?.unfocus();

    Get.dialog(
      const AddPanSheet(),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      useSafeArea: true,
    );
  }

  Future<String?> addProfile({required String name, required String pan}) async {
    final normalizedName = name.trim();
    final normalizedPan = pan.toUpperCase().trim();

    if (normalizedName.length < 2) return 'Enter a profile name.';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(normalizedPan)) {
      return 'Enter a valid PAN, e.g. ABCDE1234F.';
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final profile = PanProfile(
      id: id,
      name: normalizedName,
      maskedPan: Formatters.maskPan(normalizedPan),
      isDefault: profiles.isEmpty,
    );

    await _secureStorage.savePan(id, normalizedPan);
    profiles.add(profile);
    await _persist();
    return null;
  }

  Future<void> setDefault(String id) async {
    profiles.assignAll(
      profiles
          .map((profile) => profile.copyWith(isDefault: profile.id == id))
          .toList(),
    );
    await _persist();
  }

  Future<void> deleteProfile(PanProfile profile) async {
    await _secureStorage.deletePan(profile.id);
    profiles.removeWhere((item) => item.id == profile.id);

    if (profiles.isNotEmpty && !profiles.any((item) => item.isDefault)) {
      profiles[0] = profiles[0].copyWith(isDefault: true);
      profiles.refresh();
    }

    await _persist();
  }

  PanProfile? byId(String id) => profiles.firstWhereOrNull((item) => item.id == id);

  Future<void> _persist() => _storage.writeProfiles(profiles);
}

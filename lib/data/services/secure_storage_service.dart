import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/constants/storage_keys.dart';

class SecureStorageService extends GetxService {
  static const _storage = FlutterSecureStorage();

  Future<void> savePan(String profileId, String pan) {
    return _storage.write(
      key: StorageKeys.pan(profileId),
      value: pan.toUpperCase().trim(),
    );
  }

  Future<String?> readPan(String profileId) {
    return _storage.read(key: StorageKeys.pan(profileId));
  }

  Future<void> deletePan(String profileId) {
    return _storage.delete(key: StorageKeys.pan(profileId));
  }
}

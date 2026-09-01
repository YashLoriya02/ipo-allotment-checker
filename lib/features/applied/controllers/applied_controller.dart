import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/ipo.dart';
import '../../../data/models/ipo_application.dart';
import '../../../data/models/pan_profile.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../../data/services/local_storage_service.dart';
import '../../profile/controllers/profile_controller.dart';

class AppliedController extends GetxController {
  AppliedController()
      : _storage = Get.find<LocalStorageService>(),
        _repository = Get.find<IpoRepository>(),
        _profileController = Get.find<ProfileController>();

  final LocalStorageService _storage;
  final IpoRepository _repository;
  final ProfileController _profileController;

  final applications = <IpoApplication>[].obs;
  final selectedCompleted = false.obs;

  @override
  void onInit() {
    super.onInit();
    applications.assignAll(_storage.readApplications());
  }

  int get activeCount => applications.where((item) => !item.isCompleted).length;
  int get completedCount => applications.where((item) => item.isCompleted).length;

  List<IpoApplication> get visibleApplications {
    final completed = selectedCompleted.value;
    final items = applications
        .where((item) => item.isCompleted == completed)
        .toList();
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  Future<Ipo?> ipoFor(IpoApplication application) =>
      _repository.getById(application.ipoId);

  PanProfile? profileFor(IpoApplication application) =>
      _profileController.byId(application.panProfileId);

  bool isApplied(String ipoId) =>
      applications.any((item) => item.ipoId == ipoId);

  int appliedProfileCount(String ipoId) =>
      applications.where((item) => item.ipoId == ipoId).length;

  bool isAppliedWithProfile(String ipoId, String profileId) =>
      applications.any(
        (item) => item.ipoId == ipoId && item.panProfileId == profileId,
      );

  Future<bool> addApplication(Ipo ipo, PanProfile profile) async {
    if (isAppliedWithProfile(ipo.id, profile.id)) {
      Get.snackbar(
        'Already added',
        '${ipo.symbol} is already tracked for ${profile.name}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    applications.add(
      IpoApplication(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        ipoId: ipo.id,
        panProfileId: profile.id,
        addedAt: DateTime.now(),
        status: ApplicationStatus.waiting,
      ),
    );

    await _persist();
    Get.snackbar(
      'Added to Applied',
      '${ipo.symbol} will be tracked for ${profile.name}.',
      snackPosition: SnackPosition.BOTTOM,
      icon: const Icon(Icons.check_circle_rounded),
    );
    return true;
  }

  Future<void> removeApplication(IpoApplication application) async {
    applications.removeWhere((item) => item.id == application.id);
    await _persist();
  }

  int usageCountForProfile(String profileId) =>
      applications.where((item) => item.panProfileId == profileId).length;

  int activeUsageCountForProfile(String profileId) => applications
      .where((item) => item.panProfileId == profileId && !item.isCompleted)
      .length;

  Future<void> _persist() => _storage.writeApplications(applications);
}

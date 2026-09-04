import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/allotment_check_result.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/ipo_application.dart';
import '../../../data/models/pan_profile.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../../data/services/kfin_allotment_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../profile/controllers/profile_controller.dart';

class AppliedController extends GetxController {
  AppliedController()
      : _storage = Get.find<LocalStorageService>(),
        _secureStorage = Get.find<SecureStorageService>(),
        _kfin = Get.find<KfinAllotmentService>(),
        _repository = Get.find<IpoRepository>(),
        _profileController = Get.find<ProfileController>();

  final LocalStorageService _storage;
  final SecureStorageService _secureStorage;
  final KfinAllotmentService _kfin;
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

  Future<Ipo?> ipoFor(IpoApplication application) async {
    final ipo = await _repository.getById(application.ipoId);
    if (ipo != null) {
      await _storage.upsertCachedIpo(ipo);
    }
    return ipo;
  }

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

  bool supportsRegistrar(Ipo ipo) => _kfin.supportsRegistrar(ipo);

  Future<bool> addApplication(Ipo ipo, PanProfile profile) async {
    if (isAppliedWithProfile(ipo.id, profile.id)) {
      Get.snackbar(
        'Already added',
        '${ipo.symbol} is already tracked for ${profile.name}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    await _storage.upsertCachedIpo(ipo);

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
    return true;
  }

  Future<void> checkAllotment(
    IpoApplication application,
    Ipo ipo,
  ) async {
    final index = applications.indexWhere((item) => item.id == application.id);
    if (index == -1) return;

    final current = applications[index];
    if (current.isCompleted || current.status == ApplicationStatus.checking) {
      return;
    }

    final profile = profileFor(current);
    if (profile == null) {
      Get.snackbar(
        'PAN profile unavailable',
        'This application no longer has a PAN profile.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final pan = await _secureStorage.readPan(current.panProfileId);
    if (pan == null || pan.trim().isEmpty) {
      Get.snackbar(
        'PAN unavailable',
        'The PAN for ${profile.name} could not be found in secure storage.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_kfin.supportsRegistrar(ipo)) {
      final updated = current.copyWith(
        status: ApplicationStatus.unsupportedRegistrar,
        lastCheckedAt: DateTime.now(),
        lastMessage: 'This registrar checker is not available yet.',
      );
      _replaceApplication(index, updated);
      await _persist();
      await _notify(ipo, updated);
      _showResultFeedback(ipo, updated);
      return;
    }

    _replaceApplication(
      index,
      current.copyWith(
        status: ApplicationStatus.checking,
        clearLastMessage: true,
      ),
    );

    try {
      final result = await _kfin.checkAllotment(
        ipo: ipo,
        pan: pan,
      );

      final latestIndex = applications.indexWhere(
        (item) => item.id == application.id,
      );
      if (latestIndex == -1) return;

      final latest = applications[latestIndex];
      final updated = latest.copyWith(
        status: _mapStatus(result.status),
        lastCheckedAt: DateTime.now(),
        allottedShares: result.sharesAllotted,
        applicationNumber: result.applicationNumber,
        lastMessage: result.message,
        clearAllottedShares: result.sharesAllotted == null,
        clearApplicationNumber: result.applicationNumber == null,
        clearLastMessage: result.message == null,
      );

      _replaceApplication(latestIndex, updated);
      await _persist();
      _showResultFeedback(ipo, updated);
      await _notify(ipo, updated);
    } on KfinAllotmentException catch (error) {
      await _markTemporaryError(
        applicationId: application.id,
        ipo: ipo,
        message: error.message,
      );
    } catch (_) {
      await _markTemporaryError(
        applicationId: application.id,
        ipo: ipo,
        message: 'KFin could not be reached right now.',
      );
    }
  }

  ApplicationStatus _mapStatus(AllotmentApiStatus status) {
    return switch (status) {
      AllotmentApiStatus.allotted => ApplicationStatus.allotted,
      AllotmentApiStatus.notAllotted => ApplicationStatus.notAllotted,
      AllotmentApiStatus.noRecord => ApplicationStatus.noRecord,
      AllotmentApiStatus.notLive => ApplicationStatus.resultNotLive,
      AllotmentApiStatus.humanRequired => ApplicationStatus.humanRequired,
      AllotmentApiStatus.temporaryError => ApplicationStatus.temporaryError,
      AllotmentApiStatus.unsupportedRegistrar =>
        ApplicationStatus.unsupportedRegistrar,
      AllotmentApiStatus.unknown => ApplicationStatus.unknown,
    };
  }

  Future<void> _markTemporaryError({
    required String applicationId,
    required Ipo ipo,
    required String message,
  }) async {
    final index = applications.indexWhere((item) => item.id == applicationId);
    if (index == -1) return;

    final updated = applications[index].copyWith(
      status: ApplicationStatus.temporaryError,
      lastCheckedAt: DateTime.now(),
      lastMessage: message,
    );

    _replaceApplication(index, updated);
    await _persist();
    _showResultFeedback(ipo, updated);
    await _notify(ipo, updated);
  }

  Future<void> _notify(Ipo ipo, IpoApplication application) async {
    try {
      await LocalNotificationService.instance.showManualCheckResult(
        ipo: ipo,
        application: application,
      );
    } catch (_) {
      // Notification failure must never break the allotment result flow.
    }
  }

  void _showResultFeedback(Ipo ipo, IpoApplication application) {
    switch (application.status) {
      case ApplicationStatus.allotted:
        Get.snackbar(
          'Allotted 🎉',
          application.allottedShares == null
              ? '${ipo.symbol} allotment found.'
              : '${application.allottedShares} shares allotted in ${ipo.symbol}.',
          snackPosition: SnackPosition.BOTTOM,
          icon: const Icon(Icons.celebration_rounded),
        );
        break;
      case ApplicationStatus.notAllotted:
        Get.snackbar(
          'Not allotted',
          'No shares were allotted in ${ipo.symbol}.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.noRecord:
        Get.snackbar(
          'No record found',
          'KFin could not find an allotment record for this PAN and IPO.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.resultNotLive:
        Get.snackbar(
          'Result not live yet',
          'The allotment result is not available yet.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.humanRequired:
        Get.snackbar(
          'Verification required',
          'The registrar requires manual verification.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.unsupportedRegistrar:
        Get.snackbar(
          'Registrar not supported',
          application.lastMessage ?? 'This registrar checker is not available yet.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.unknown:
        Get.snackbar(
          'Could not complete check',
          application.lastMessage ?? 'Please try again later.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.temporaryError:
        Get.snackbar(
          'Temporary issue',
          application.lastMessage ?? 'KFin could not complete this request.',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
      case ApplicationStatus.waiting:
      case ApplicationStatus.checking:
        break;
    }
  }

  void _replaceApplication(int index, IpoApplication value) {
    applications[index] = value;
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

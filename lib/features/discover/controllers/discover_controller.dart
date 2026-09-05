import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/ipo.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../../data/services/local_storage_service.dart';

class DiscoverController extends GetxController {
  DiscoverController()
    : _repository = Get.find<IpoRepository>(),
      _storage = Get.find<LocalStorageService>();

  final IpoRepository _repository;
  final LocalStorageService _storage;

  final searchController = TextEditingController();
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = RxnString();
  final allIpos = <Ipo>[].obs;
  final selectedStatus = IpoStatus.open.obs;
  final selectedType = Rxn<IpoType>();
  final searchQuery = ''.obs;
  final lastUpdated = Rxn<DateTime>();

  bool get hasCachedData => allIpos.isNotEmpty;
  bool get showingStaleData => errorMessage.value != null && allIpos.isNotEmpty;
  String get lastUpdatedLabel => Formatters.lastUpdated(lastUpdated.value);

  @override
  void onInit() {
    super.onInit();
    reloadFromStorage();
    load();
  }

  void reloadFromStorage() {
    final savedType = _storage.readDiscoverIpoType();
    selectedType.value = switch (savedType) {
      'mainboard' => IpoType.mainboard,
      'sme' => IpoType.sme,
      _ => null,
    };

    final cached = _storage.readCachedIpos();
    allIpos.assignAll(cached);
    lastUpdated.value = _storage.readLastIpoRefresh();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final initialLoad = allIpos.isEmpty;
    if (initialLoad) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }
    errorMessage.value = null;

    try {
      final fresh = await _repository.getIpos();
      allIpos.assignAll(fresh);

      final now = DateTime.now();
      lastUpdated.value = now;
      await Future.wait([
        _storage.writeCachedIpos(fresh),
        _storage.writeLastIpoRefresh(now),
      ]);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  void setStatus(IpoStatus value) => selectedStatus.value = value;

  Future<void> setType(IpoType? value) async {
    selectedType.value = value;
    await _storage.writeDiscoverIpoType(value?.name);
  }

  void setSearch(String value) => searchQuery.value = value.trim();

  Future<void> clearFilters() async {
    searchController.clear();
    searchQuery.value = '';
    await setType(null);
  }

  List<Ipo> get filteredIpos {
    final query = searchQuery.value.toLowerCase();
    final searching = query.isNotEmpty;

    final result = allIpos.where((ipo) {
      final matchesStatus = searching || ipo.status == selectedStatus.value;
      final matchesType =
          selectedType.value == null || ipo.type == selectedType.value;
      final matchesSearch =
          !searching ||
          ipo.name.toLowerCase().contains(query) ||
          ipo.symbol.toLowerCase().contains(query) ||
          (ipo.registrarName?.toLowerCase().contains(query) ?? false) ||
          (ipo.registrarCode?.toLowerCase().contains(query) ?? false);
      return matchesStatus && matchesType && matchesSearch;
    }).toList();

    result.sort((a, b) {
      DateTime? relevant(Ipo ipo) => switch (ipo.status) {
        IpoStatus.open => ipo.closeDate,
        IpoStatus.upcoming => ipo.openDate,
        IpoStatus.closed => ipo.allotmentDate ?? ipo.closeDate,
        IpoStatus.listed => ipo.listingDate ?? ipo.closeDate,
      };

      final aDate = relevant(a);
      final bDate = relevant(b);
      if (aDate == null && bDate == null) return a.name.compareTo(b.name);
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      if (searching) return bDate.compareTo(aDate);

      final historical =
          selectedStatus.value == IpoStatus.closed ||
          selectedStatus.value == IpoStatus.listed;
      return historical ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return result;
  }

  int countForStatus(IpoStatus status) =>
      allIpos.where((ipo) => ipo.status == status).length;
}

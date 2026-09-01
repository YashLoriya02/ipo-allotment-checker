import 'package:get/get.dart';

import '../../../data/models/ipo.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../../data/services/local_storage_service.dart';

class DiscoverController extends GetxController {
  DiscoverController()
    : _repository = Get.find<IpoRepository>(),
      _storage = Get.find<LocalStorageService>();

  final IpoRepository _repository;
  final LocalStorageService _storage;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final allIpos = <Ipo>[].obs;
  final selectedStatus = IpoStatus.open.obs;
  final selectedType = Rxn<IpoType>();
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final savedType = _storage.readDiscoverIpoType();
    selectedType.value = switch (savedType) {
      'mainboard' => IpoType.mainboard,
      'sme' => IpoType.sme,
      _ => null,
    };
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      allIpos.assignAll(await _repository.getIpos());
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setStatus(IpoStatus value) => selectedStatus.value = value;

  Future<void> setType(IpoType? value) async {
    selectedType.value = value;
    await _storage.writeDiscoverIpoType(value?.name);
  }

  void setSearch(String value) => searchQuery.value = value.trim();

  List<Ipo> get filteredIpos {
    final query = searchQuery.value.toLowerCase();
    final searching = query.isNotEmpty;

    final result = allIpos.where((ipo) {
      // Search is global across every IPO lifecycle bucket. The selected
      // Mainboard/SME filter is still respected because that is a user preference.
      final matchesStatus = searching || ipo.status == selectedStatus.value;
      final matchesType =
          selectedType.value == null || ipo.type == selectedType.value;
      final matchesSearch =
          !searching ||
          ipo.name.toLowerCase().contains(query) ||
          ipo.symbol.toLowerCase().contains(query) ||
          (ipo.registrarName?.toLowerCase().contains(query) ?? false);
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

      // Closed/listed are history views: newest first. Open/upcoming are
      // action-oriented: nearest date first.
      final bothHistorical =
          !searching &&
          (selectedStatus.value == IpoStatus.closed ||
              selectedStatus.value == IpoStatus.listed);
      return bothHistorical ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return result;
  }

  int countForStatus(IpoStatus status) =>
      allIpos.where((ipo) => ipo.status == status).length;
}

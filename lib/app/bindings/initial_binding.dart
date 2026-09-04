import 'package:get/get.dart';

import '../../data/repositories/ipo_repository.dart';
import '../../data/repositories/upstox_ipo_repository.dart';
import '../../data/services/kfin_allotment_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/secure_storage_service.dart';
import '../../features/applied/controllers/applied_controller.dart';
import '../../features/discover/controllers/discover_controller.dart';
import '../../features/profile/controllers/profile_controller.dart';
import '../../features/profile/controllers/theme_controller.dart';
import '../../features/shell/controllers/shell_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(LocalStorageService(), permanent: true);
    Get.put(SecureStorageService(), permanent: true);
    Get.put(KfinAllotmentService(), permanent: true);
    Get.put<IpoRepository>(UpstoxIpoRepository(), permanent: true);

    Get.put(ThemeController(), permanent: true);
    Get.put(ShellController(), permanent: true);
    Get.put(ProfileController(), permanent: true);
    Get.put(DiscoverController(), permanent: true);
    Get.put(AppliedController(), permanent: true);
  }
}

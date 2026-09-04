import 'package:get/get.dart';
import 'package:ipo_allotment_tracker/features/details/views/ipo_detail_view.dart';
import 'package:ipo_allotment_tracker/features/shell/views/shell_view.dart';

import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.shell, page: () => const ShellView()),
    GetPage(name: AppRoutes.details, page: () => const IpoDetailView()),
  ];
}

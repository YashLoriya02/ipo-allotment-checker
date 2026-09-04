import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../applied/views/applied_view.dart';
import '../../discover/views/discover_view.dart';
import '../../profile/views/profile_view.dart';
import '../controllers/shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    const screens = <Widget>[
      DiscoverView(),
      AppliedView(),
      ProfileView(),
    ];

    return Obx(
      () => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: controller.selectedIndex.value,
            children: screens,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Applied',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

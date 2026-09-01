import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/ipo_application.dart';
import '../../shell/controllers/shell_controller.dart';
import '../controllers/applied_controller.dart';
import '../widgets/application_card.dart';

class AppliedView extends GetView<AppliedController> {
  const AppliedView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Applications', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  'Everything you applied to, in one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Obx(
                  () => SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Active'), icon: Icon(Icons.schedule_rounded)),
                      ButtonSegment(value: true, label: Text('Completed'), icon: Icon(Icons.task_alt_rounded)),
                    ],
                    selected: {controller.selectedCompleted.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) => controller.selectedCompleted.value = values.first,
                  ),
                ),
              ],
            ),
          ),
        ),
        Obx(() {
          final items = controller.visibleApplications;
          if (items.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: controller.selectedCompleted.value
                    ? Icons.task_alt_rounded
                    : Icons.bookmark_add_outlined,
                title: controller.selectedCompleted.value
                    ? 'No completed applications yet'
                    : 'Nothing tracked yet',
                message: controller.selectedCompleted.value
                    ? 'Completed allotment results will stay here.'
                    : 'Open an IPO and tap “I applied to this IPO”.',
                actionLabel: controller.selectedCompleted.value ? null : 'Browse IPOs',
                onAction: controller.selectedCompleted.value
                    ? null
                    : () => Get.find<ShellController>().changeTab(0),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _AsyncApplicationCard(
                application: items[index],
                controller: controller,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AsyncApplicationCard extends StatelessWidget {
  const _AsyncApplicationCard({required this.application, required this.controller});

  final IpoApplication application;
  final AppliedController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Ipo?>(
      future: controller.ipoFor(application),
      builder: (context, snapshot) {
        final ipo = snapshot.data;
        if (ipo == null) {
          return Container(
            height: 130,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
          );
        }

        return ApplicationCard(
          application: application,
          ipo: ipo,
          profile: controller.profileFor(application),
          onRemove: () => controller.removeApplication(application),
        );
      },
    );
  }
}

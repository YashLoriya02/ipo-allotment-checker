import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                  'Your IPO applications and allotment timeline.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Obx(
                  () => Row(
                    children: [
                      Expanded(
                        child: _ApplicationTab(
                          label: 'Active',
                          count: controller.activeCount,
                          icon: Icons.schedule_rounded,
                          selected: !controller.selectedCompleted.value,
                          onTap: () => controller.selectedCompleted.value = false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ApplicationTab(
                          label: 'Completed',
                          count: controller.completedCount,
                          icon: Icons.task_alt_rounded,
                          selected: controller.selectedCompleted.value,
                          onTap: () => controller.selectedCompleted.value = true,
                        ),
                      ),
                    ],
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
                    ? 'Allotment results will stay here once checking is enabled.'
                    : 'Open an IPO and tap “I applied to this IPO”. You can track the same IPO for multiple PAN profiles.',
                actionLabel: controller.selectedCompleted.value ? null : 'Browse IPOs',
                onAction: controller.selectedCompleted.value
                    ? null
                    : () => Get.find<ShellController>().changeTab(0),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
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

class _ApplicationTab extends StatelessWidget {
  const _ApplicationTab({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.11) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary.withValues(alpha: 0.35) : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: selected ? primary : null),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? primary : null)),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? primary.withValues(alpha: 0.14) : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncApplicationCard extends StatelessWidget {
  const _AsyncApplicationCard({
    required this.application,
    required this.controller,
  });

  final IpoApplication application;
  final AppliedController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Ipo?>(
      future: controller.ipoFor(application),
      builder: (context, snapshot) {
        final ipo = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting && ipo == null) {
          return const _ApplicationSkeleton();
        }

        if (ipo == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IPO details unavailable', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        'The application is saved. Reopen this tab when you are online.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ApplicationCard(
          application: application,
          ipo: ipo,
          profile: controller.profileFor(application),
          onRemove: () => _confirmRemove(context),
        );
      },
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final remove = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Remove application?'),
        content: const Text(
          'This only removes the IPO from your Applied list. Your PAN profile will stay saved.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Get.back(result: true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (remove == true) {
      await controller.removeApplication(application);
    }
  }
}

class _ApplicationSkeleton extends StatelessWidget {
  const _ApplicationSkeleton();

  @override
  Widget build(BuildContext context) {
    final bone = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      height: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: bone, borderRadius: BorderRadius.circular(15))),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 16, decoration: BoxDecoration(color: bone, borderRadius: BorderRadius.circular(7)))),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 40, decoration: BoxDecoration(color: bone.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 18),
          Container(height: 34, decoration: BoxDecoration(color: bone.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(9))),
        ],
      ),
    );
  }
}

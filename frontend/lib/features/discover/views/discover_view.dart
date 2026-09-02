import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/ipo.dart';
import '../controllers/discover_controller.dart';
import '../widgets/ipo_card.dart';

class DiscoverView extends GetView<DiscoverController> {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _Header(controller: controller)),
          SliverToBoxAdapter(child: _StatusSelector(controller: controller)),
          SliverToBoxAdapter(child: _TypeSelector(controller: controller)),
          Obx(() {
            if (controller.isRefreshing.value &&
                controller.allIpos.isNotEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 4),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),
          Obx(() {
            if (controller.showingStaleData) {
              return SliverToBoxAdapter(
                child: _CachedDataBanner(
                  message: controller.errorMessage.value!,
                  onRetry: controller.load,
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),
          Obx(() {
            if (controller.isLoading.value && controller.allIpos.isEmpty) {
              return const SliverToBoxAdapter(child: _SkeletonList());
            }

            if (controller.errorMessage.value != null &&
                controller.allIpos.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load IPOs',
                  message: controller.errorMessage.value!,
                  actionLabel: 'Retry',
                  onAction: controller.load,
                ),
              );
            }

            final items = controller.filteredIpos;
            if (items.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No IPOs found',
                  message: controller.searchQuery.value.isNotEmpty
                      ? 'No IPO matches your search and type filter.'
                      : 'Try another status or IPO type.',
                  actionLabel: 'Clear filters',
                  onAction: controller.clearFilters,
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              sliver: SliverList.separated(
                itemCount: items.length,
                itemBuilder: (_, index) => IpoCard(ipo: items[index]),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover IPOs',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track the IPOs you actually apply to.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              controller.showingStaleData
                  ? Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (controller.showingStaleData
                                      ? AppColors.amber
                                      : AppColors.mint)
                                  .withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'CACHED',
                          style: TextStyle(
                            color: controller.showingStaleData
                                ? AppColors.amber
                                : AppColors.mint,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.55,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 5),
          Obx(
            () => Text(
              controller.lastUpdatedLabel,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller.searchController,
            onChanged: controller.setSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search all IPOs, symbol, registrar…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Obx(
                () => controller.searchQuery.value.isEmpty
                    ? const Icon(Icons.tune_rounded)
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.searchController.clear();
                          controller.setSearch('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        children:
            const [
              IpoStatus.open,
              IpoStatus.closed,
              IpoStatus.listed,
              IpoStatus.upcoming,
            ].map((status) {
              return Obx(() {
                final selected = controller.selectedStatus.value == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => controller.setStatus(status),
                    label: Text(
                      '${_statusLabel(status)}  ${controller.countForStatus(status)}',
                    ),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              });
            }).toList(),
      ),
    );
  }

  String _statusLabel(IpoStatus status) => switch (status) {
    IpoStatus.open => 'Open',
    IpoStatus.closed => 'Closed',
    IpoStatus.listed => 'Listed',
    IpoStatus.upcoming => 'Upcoming',
  };
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.controller});
  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(
        () => Row(
          children: [
            _TypeChip(
              label: 'All',
              selected: controller.selectedType.value == null,
              onTap: () => controller.setType(null),
            ),
            const SizedBox(width: 8),
            _TypeChip(
              label: 'Mainboard',
              selected: controller.selectedType.value == IpoType.mainboard,
              onTap: () => controller.setType(IpoType.mainboard),
            ),
            const SizedBox(width: 8),
            _TypeChip(
              label: 'SME',
              selected: controller.selectedType.value == IpoType.sme,
              onTap: () => controller.setType(IpoType.sme),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _CachedDataBanner extends StatelessWidget {
  const _CachedDataBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.amber,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Showing saved IPO data. Pull down or retry when online.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: message,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    _Bone(width: 46, height: 46, radius: 15, color: base),
                    const SizedBox(width: 12),
                    Expanded(child: _Bone(height: 17, radius: 7, color: base)),
                    const SizedBox(width: 24),
                    _Bone(width: 58, height: 24, radius: 12, color: base),
                  ],
                ),
                const SizedBox(height: 18),
                _Bone(width: 120, height: 12, radius: 6, color: base),
                const SizedBox(height: 10),
                _Bone(width: 190, height: 22, radius: 7, color: base),
                const SizedBox(height: 18),
                _Bone(height: 1, radius: 1, color: base),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Bone(height: 34, radius: 8, color: base)),
                    const SizedBox(width: 12),
                    Expanded(child: _Bone(height: 34, radius: 8, color: base)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    this.width,
    required this.height,
    required this.radius,
    required this.color,
  });
  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

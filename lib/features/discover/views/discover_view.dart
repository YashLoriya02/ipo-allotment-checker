import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        slivers: [
          SliverToBoxAdapter(child: _Header(controller: controller)),
          SliverToBoxAdapter(child: _StatusSelector(controller: controller)),
          SliverToBoxAdapter(child: _TypeSelector(controller: controller)),
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
                  message: 'Try another status, type, or search term.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    controller.setType(null);
                    controller.setSearch('');
                  },
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            onChanged: controller.setSearch,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search IPO, symbol, registrar…',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: Icon(Icons.tune_rounded),
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
        children: IpoStatus.values.map((status) {
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
    IpoStatus.upcoming => 'Upcoming',
    IpoStatus.closed => 'Closed',
    IpoStatus.listed => 'Listed',
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

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 190,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
          ),
        ),
      ),
    );
  }
}

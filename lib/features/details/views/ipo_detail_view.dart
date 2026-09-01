import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/pan_profile.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../applied/controllers/applied_controller.dart';
import '../../profile/controllers/profile_controller.dart';

class IpoDetailView extends StatelessWidget {
  const IpoDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = Get.arguments as Ipo;
    final applied = Get.find<AppliedController>();
    final repository = Get.find<IpoRepository>();

    return FutureBuilder<Ipo?>(
      future: repository.getById(summary.id),
      builder: (context, snapshot) {
        final ipo = snapshot.data ?? summary;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: Text(ipo.symbol),
                  actions: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () {},
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _Hero(ipo: ipo),
                      const SizedBox(height: 14),
                      _QuickStats(ipo: ipo),
                      if (ipo.totalSubscription != null ||
                          ipo.listingPrice != null ||
                          ipo.industry != null ||
                          ipo.listingExchange != null) ...[
                        const SizedBox(height: 14),
                        _MarketSnapshot(ipo: ipo),
                      ],
                      const SizedBox(height: 14),
                      _Timeline(ipo: ipo),
                      const SizedBox(height: 14),
                      _RegistrarCard(ipo: ipo),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: 14),
                        _DetailsError(message: snapshot.error.toString()),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Obx(
                () => FilledButton.icon(
                  onPressed: () => _showApplySheet(context, ipo),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  icon: Icon(
                    applied.isApplied(ipo.id)
                        ? Icons.add_rounded
                        : Icons.bookmark_add_rounded,
                  ),
                  label: Text(
                    applied.isApplied(ipo.id)
                        ? 'Add another PAN'
                        : 'I applied to this IPO',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showApplySheet(BuildContext context, Ipo ipo) {
    final profileController = Get.find<ProfileController>();
    final appliedController = Get.find<AppliedController>();

    if (profileController.profiles.isEmpty) {
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),
                Icon(
                  Icons.badge_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Add a PAN profile first',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  'Your PAN is stored securely on this device and is never shown in full.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Get.back();
                    profileController.openAddProfileSheet();
                  },
                  child: const Text('Add PAN profile'),
                ),
              ],
            ),
          ),
        ),
        isScrollControlled: true,
      );
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 16),
              Text(
                'Applied using',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose the PAN profile used for ${ipo.symbol}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => Column(
                  children: profileController.profiles.map((
                    PanProfile profile,
                  ) {
                    final alreadyAdded = appliedController.isAppliedWithProfile(
                      ipo.id,
                      profile.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        onTap: alreadyAdded
                            ? null
                            : () => appliedController.addApplication(
                                ipo,
                                profile,
                              ),
                        tileColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.10),
                          child: Icon(
                            Icons.person_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          profile.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(profile.maskedPan),
                        trailing: alreadyAdded
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.mint,
                              )
                            : const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  }).toList(),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Get.back();
                  profileController.openAddProfileSheet();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add another PAN profile'),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  Formatters.initials(ipo.name),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              StatusPill(status: ipo.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(ipo.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              _Tag(label: ipo.typeLabel),
              const SizedBox(width: 8),
              _Tag(label: ipo.issueType),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Price band',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.priceBand(ipo),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (ipo.minimumInvestment != null) ...[
            const SizedBox(height: 5),
            Text(
              'Minimum investment ≈ ${Formatters.money(ipo.minimumInvestment)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Lot size',
              value: ipo.lotSize?.toString() ?? '—',
            ),
          ),
          _Divider(),
          Expanded(
            child: _Stat(
              label: 'Issue size',
              value: ipo.issueSizeCrore == null
                  ? '—'
                  : '₹${ipo.issueSizeCrore!.toStringAsFixed(1)} Cr',
            ),
          ),
          _Divider(),
          Expanded(
            child: _Stat(label: 'Registrar', value: ipo.registrarCode ?? '—'),
          ),
        ],
      ),
    );
  }
}

class _MarketSnapshot extends StatelessWidget {
  const _MarketSnapshot({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final gain = ipo.listingGainPercent;
    final gainColor = (gain ?? 0) >= 0 ? AppColors.mint : AppColors.rose;

    return Container(
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
              Expanded(
                child: Text(
                  'Market snapshot',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (ipo.listingExchange != null)
                _Tag(label: ipo.listingExchange!),
            ],
          ),
          if (ipo.industry != null) ...[
            const SizedBox(height: 5),
            Text(
              ipo.industry!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            runSpacing: 16,
            spacing: 12,
            children: [
              if (ipo.totalSubscription != null)
                _SnapshotMetric(
                  label: 'Subscription',
                  value: '${ipo.totalSubscription!.toStringAsFixed(2)}x',
                ),
              if (ipo.cutOffPrice != null)
                _SnapshotMetric(
                  label: 'Cut-off price',
                  value: Formatters.money(ipo.cutOffPrice),
                ),
              if (ipo.listingPrice != null)
                _SnapshotMetric(
                  label: 'Listing price',
                  value:
                      Formatters.money(ipo.listingPrice) +
                      (gain != null
                          ? ' (${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%)'
                          : ''),
                  valueColor: gainColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Opens', ipo.openDate),
      ('Closes', ipo.closeDate),
      ('Allotment', ipo.allotmentDate),
      ('Listing', ipo.listingDate),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IPO timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            _TimelineRow(
              label: items[i].$1,
              date: items[i].$2,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.date,
    required this.isLast,
  });
  final String label;
  final DateTime? date;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = date == null
        ? null
        : DateTime(date!.year, date!.month, date!.day);
    final hasHappened = eventDate != null && !eventDate.isAfter(today);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: hasHappened ? primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: date == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35)
                          : primary,
                      width: 1.6,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: hasHappened
                          ? primary.withValues(alpha: 0.32)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    Formatters.fullDate(date),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrarCard extends StatelessWidget {
  const _RegistrarCard({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ipo.registrarName ?? 'Not available yet',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live IPO details could not be refreshed. Showing the latest list data instead.\n$message',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 35,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Theme.of(context).dividerColor,
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

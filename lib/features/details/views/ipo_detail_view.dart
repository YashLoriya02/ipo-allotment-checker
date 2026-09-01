import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/ipo.dart';
import '../../../data/repositories/ipo_repository.dart';
import '../../applied/controllers/applied_controller.dart';
import '../widgets/apply_ipo_dialog.dart';

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
                  title: Text(ipo.symbol.isEmpty ? 'IPO details' : ipo.symbol),
                  actions: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _Hero(ipo: ipo),
                      const SizedBox(height: 12),
                      _ContextBanner(ipo: ipo),
                      const SizedBox(height: 14),
                      _QuickStats(ipo: ipo),
                      if (_hasMarketData(ipo)) ...[
                        const SizedBox(height: 14),
                        _MarketSnapshot(ipo: ipo),
                      ],
                      const SizedBox(height: 14),
                      _Timeline(ipo: ipo),
                      if (ipo.registrarName != null ||
                          ipo.registrarCode != null) ...[
                        const SizedBox(height: 14),
                        _RegistrarCard(ipo: ipo),
                      ],
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
              child: Obx(() {
                final count = applied.appliedProfileCount(ipo.id);
                return FilledButton.icon(
                  onPressed: () => Get.dialog(
                    ApplyIpoDialog(ipo: ipo),
                    barrierDismissible: true,
                    barrierColor: Colors.black.withValues(alpha: 0.68),
                    useSafeArea: true,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  icon: Icon(
                    count > 0
                        ? Icons.person_add_alt_1_rounded
                        : Icons.bookmark_add_rounded,
                  ),
                  label: Text(
                    count > 0
                        ? 'Add another PAN · $count tracked'
                        : 'I applied to this IPO',
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  static bool _hasMarketData(Ipo ipo) =>
      ipo.totalSubscription != null ||
      ipo.listingPrice != null ||
      ipo.industry != null ||
      ipo.listingExchange != null ||
      ipo.cutOffPrice != null;
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: ipo.typeLabel),
              _Tag(label: ipo.issueType),
              if (ipo.listingExchange != null)
                _Tag(label: ipo.listingExchange!),
            ],
          ),
          if (ipo.minPrice != null || ipo.maxPrice != null) ...[
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
          ],
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

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final info = _info();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: info.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: info.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    color: info.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (info.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    info.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String? subtitle, IconData icon, Color color}) _info() {
    if (ipo.status == IpoStatus.listed) {
      final gain = ipo.listingGainPercent;
      return (
        title: ipo.listingDate == null
            ? 'Listed'
            : Formatters.isToday(ipo.listingDate)
            ? 'Listed today'
            : 'Listed ${Formatters.shortDate(ipo.listingDate)}',
        subtitle: ipo.listingPrice == null
            ? null
            : 'Opened at ${Formatters.money(ipo.listingPrice)}${gain == null ? '' : ' · ${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}% vs issue price'}',
        icon: Icons.show_chart_rounded,
        color: (gain ?? 0) >= 0 ? AppColors.mint : AppColors.rose,
      );
    }

    if (ipo.status == IpoStatus.closed) {
      return (
        title: ipo.allotmentDate == null
            ? 'Issue closed'
            : Formatters.eventRelative('Allotment', ipo.allotmentDate),
        subtitle: ipo.listingDate == null
            ? null
            : '${Formatters.eventRelative('Listing', ipo.listingDate)} · ${Formatters.fullDate(ipo.listingDate)}',
        icon: Formatters.isToday(ipo.allotmentDate)
            ? Icons.notifications_active_rounded
            : Icons.hourglass_bottom_rounded,
        color: AppColors.amber,
      );
    }

    if (ipo.status == IpoStatus.upcoming) {
      return (
        title: Formatters.eventRelative('Opens', ipo.openDate),
        subtitle: ipo.openDate == null
            ? null
            : Formatters.fullDate(ipo.openDate),
        icon: Icons.event_available_outlined,
        color: AppColors.brand,
      );
    }

    return (
      title: Formatters.eventRelative('Closes', ipo.closeDate),
      subtitle: ipo.closeDate == null
          ? null
          : Formatters.fullDate(ipo.closeDate),
      icon: Icons.timelapse_rounded,
      color: AppColors.mint,
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final stats = <({String label, String value})>[
      if (ipo.lotSize != null) (label: 'Lot size', value: '${ipo.lotSize}'),
      if (ipo.issueSizeCrore != null)
        (
          label: 'Issue size',
          value: '₹${ipo.issueSizeCrore!.toStringAsFixed(1)} Cr',
        ),
      if (ipo.registrarCode != null)
        (label: 'Registrar', value: ipo.registrarCode!),
    ];

    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(
              child: _Stat(label: stats[i].label, value: stats[i].value),
            ),
            if (i != stats.length - 1) const _Divider(),
          ],
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
                  ipo.status == IpoStatus.listed
                      ? 'Listing performance'
                      : 'Market snapshot',
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
            runSpacing: 12,
            spacing: 12,
            children: [
              if (ipo.totalSubscription != null)
                _SnapshotMetric(
                  label: 'Subscription',
                  value: '${ipo.totalSubscription!.toStringAsFixed(2)}x',
                ),
              if (ipo.cutOffPrice != null)
                _SnapshotMetric(
                  label: 'Issue / cut-off',
                  value: Formatters.money(ipo.cutOffPrice),
                ),
              if (ipo.listingPrice != null)
                _SnapshotMetric(
                  label: 'Listing price',
                  value:
                      '${Formatters.money(ipo.listingPrice)} (${gain != null && gain >= 0 ? '+' : ''}${(gain ?? 0).toStringAsFixed(2)}%)',
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
    final today = Formatters.dateOnly(DateTime.now());
    final eventDate = date == null ? null : Formatters.dateOnly(date!);
    final hasHappened = eventDate != null && !eventDate.isAfter(today);
    final isToday = eventDate == today;

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
                  width: isToday ? 13 : 11,
                  height: isToday ? 13 : 11,
                  decoration: BoxDecoration(
                    color: hasHappened ? primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: date == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35)
                          : primary,
                      width: isToday ? 2 : 1.6,
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.24),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.fullDate(date),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          Formatters.relativeDay(date),
                          style: TextStyle(
                            color: isToday
                                ? primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
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
                  ipo.registrarName ?? ipo.registrarCode!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (ipo.registrarCode != null &&
                    ipo.registrarName != null &&
                    !ipo.registrarName!.toUpperCase().contains(
                      ipo.registrarCode!.toUpperCase(),
                    )) ...[
                  const SizedBox(height: 2),
                  Text(
                    ipo.registrarCode!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
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
              'Live details could not be refreshed. Showing saved/basic IPO data instead.\n$message',
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
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 35,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Theme.of(context).dividerColor,
  );
}

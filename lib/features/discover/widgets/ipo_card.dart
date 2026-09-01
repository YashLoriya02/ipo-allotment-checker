import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/ipo.dart';
import '../../../data/repositories/ipo_repository.dart';

class IpoCard extends StatelessWidget {
  const IpoCard({super.key, required this.ipo});

  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    if (ipo.status == IpoStatus.closed || ipo.status == IpoStatus.listed) {
      return FutureBuilder<Ipo?>(
        future: Get.find<IpoRepository>().getById(ipo.id),
        builder: (context, snapshot) => _CardBody(ipo: snapshot.data ?? ipo),
      );
    }
    return _CardBody(ipo: ipo);
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final todayTag = _todayTag(ipo);

    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.details, arguments: ipo),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    Formatters.initials(ipo.name),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ipo.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ipo.symbol,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(status: ipo.status),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MiniTag(label: ipo.typeLabel),
                _MiniTag(label: ipo.issueType.replaceAll(' Issue', '')),
                if (todayTag != null) _TodayBadge(label: todayTag),
                if (todayTag == null &&
                    ipo.status == IpoStatus.closed &&
                    _isListed(ipo))
                  const _MiniTag(label: 'LISTED'),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Price band',
                    value: Formatters.priceBand(ipo),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: ipo.lotSize != null ? 'Lot size' : 'Issue size',
                    value: ipo.lotSize?.toString() ?? _issueSize(ipo),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: _dateLabel(ipo),
                    value: Formatters.shortDate(_dateFor(ipo)),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (ipo.listingPrice != null) ...[
              const SizedBox(height: 16),
              _ListingStrip(ipo: ipo),
            ],
            const SizedBox(height: 17),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _contextText(ipo),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(Ipo ipo) => switch (ipo.status) {
    IpoStatus.open => 'Closes',
    IpoStatus.upcoming => 'Opens',
    IpoStatus.closed => ipo.allotmentDate != null ? 'Allotment' : 'Closed',
    IpoStatus.listed => ipo.listingDate != null ? 'Listed' : 'Closed',
  };

  static DateTime? _dateFor(Ipo ipo) => switch (ipo.status) {
    IpoStatus.open => ipo.closeDate,
    IpoStatus.upcoming => ipo.openDate,
    IpoStatus.closed => ipo.allotmentDate ?? ipo.closeDate,
    IpoStatus.listed => ipo.listingDate ?? ipo.closeDate,
  };

  static String _contextText(Ipo ipo) => switch (ipo.status) {
    IpoStatus.open =>
      ipo.totalSubscription == null
          ? 'Open for subscription'
          : '${ipo.totalSubscription!.toStringAsFixed(2)}x subscribed',
    IpoStatus.upcoming => 'Opening ${Formatters.shortDate(ipo.openDate)}',
    IpoStatus.closed =>
      ipo.registrarCode == null
          ? 'Tap for allotment & registrar details'
          : 'Registrar: ${ipo.registrarCode}',
    IpoStatus.listed =>
      ipo.listingExchange == null
          ? 'Issue completed'
          : 'Listed on ${ipo.listingExchange}',
  };

  static String _issueSize(Ipo ipo) {
    final size = ipo.issueSizeCrore;
    if (size == null) return '—';
    return '₹${size.toStringAsFixed(size.truncateToDouble() == size ? 0 : 1)} Cr';
  }

  static String? _todayTag(Ipo ipo) {
    final today = DateTime.now();
    if (_sameDay(ipo.allotmentDate, today)) return 'ALLOTMENT TODAY';
    if (_sameDay(ipo.listingDate, today)) return 'LISTED TODAY';
    return null;
  }

  static bool _isListed(Ipo ipo) {
    final listing = ipo.listingDate;
    if (ipo.status == IpoStatus.listed) return true;
    if (listing == null) return false;
    final today = _dateOnly(DateTime.now());
    return !_dateOnly(listing).isAfter(today);
  }

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _ListingStrip extends StatelessWidget {
  const _ListingStrip({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    final gain = ipo.listingGainPercent;
    final positive = (gain ?? 0) >= 0;
    final color = positive ? AppColors.mint : AppColors.rose;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listing price',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.money(ipo.listingPrice),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (gain != null)
            Text(
              '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = label.startsWith('LISTED') ? AppColors.mint : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

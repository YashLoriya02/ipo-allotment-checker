import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/ipo_application.dart';
import '../../../data/models/pan_profile.dart';

class ApplicationCard extends StatelessWidget {
  const ApplicationCard({
    super.key,
    required this.application,
    required this.ipo,
    required this.profile,
    required this.onRemove,
    this.onCheck,
  });

  final IpoApplication application;
  final Ipo ipo;
  final PanProfile? profile;
  final VoidCallback onRemove;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _stateVisual(application.status, ipo);
    final isChecking = application.status == ApplicationStatus.checking;

    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.details, arguments: ipo),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    Formatters.initials(ipo.name),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ipo.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _MiniTag(label: ipo.typeLabel),
                          if (profile != null)
                            _MiniTag(
                              label: '${profile!.name} · ${profile!.maskedPan}',
                            ),
                          if (profile == null)
                            const _MiniTag(label: 'PAN profile removed'),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Application options',
                  onSelected: (value) {
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 19),
                          SizedBox(width: 10),
                          Text('Remove from Applied'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: state.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: state.color.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  if (isChecking)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: state.color,
                      ),
                    )
                  else
                    Icon(state.icon, color: state.color, size: 18),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      state.label,
                      style: TextStyle(
                        color: state.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (application.status == ApplicationStatus.allotted &&
                      application.allottedShares != null)
                    Text(
                      '${application.allottedShares} shares',
                      style: TextStyle(
                        color: state.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ),
            if (application.lastMessage != null &&
                application.lastMessage!.trim().isNotEmpty &&
                application.status != ApplicationStatus.allotted &&
                application.status != ApplicationStatus.notAllotted) ...[
              const SizedBox(height: 8),
              Text(
                application.lastMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (application.lastCheckedAt != null) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _lastCheckedText(context, application.lastCheckedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Meta(
                    label: 'Allotment',
                    value: Formatters.shortDate(ipo.allotmentDate),
                    helper: ipo.allotmentDate == null
                        ? null
                        : Formatters.relativeDay(ipo.allotmentDate),
                  ),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Listing',
                    value: Formatters.shortDate(ipo.listingDate),
                    helper: ipo.listingDate == null
                        ? null
                        : Formatters.relativeDay(ipo.listingDate),
                  ),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Registrar',
                    value: ipo.registrarCode ?? 'Pending',
                    end: true,
                  ),
                ),
              ],
            ),
            if (!application.isCompleted) ...[
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isChecking ? null : onCheck,
                  icon: isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          onCheck == null
                              ? Icons.lock_clock_rounded
                              : Icons.fact_check_outlined,
                          size: 18,
                        ),
                  label: Text(
                    isChecking
                        ? 'Checking KFin...'
                        : onCheck == null
                        ? 'Registrar checker coming soon'
                        : 'Check allotment',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _lastCheckedText(BuildContext context, DateTime value) {
    final now = DateTime.now();
    final date = Formatters.dateOnly(value);
    final today = Formatters.dateOnly(now);
    final time = TimeOfDay.fromDateTime(value).format(context);

    if (date == today) return 'Last checked today at $time';
    return 'Last checked ${Formatters.shortDate(value)} at $time';
  }

  ({String label, IconData icon, Color color}) _stateVisual(
    ApplicationStatus status,
    Ipo ipo,
  ) {
    if (status == ApplicationStatus.waiting) {
      final allotment = ipo.allotmentDate;
      if (allotment != null) {
        final today = Formatters.dateOnly(DateTime.now());
        final date = Formatters.dateOnly(allotment);
        final days = date.difference(today).inDays;

        if (days == 0) {
          return (
            label: 'Allotment expected today',
            icon: Icons.notifications_active_outlined,
            color: AppColors.amber,
          );
        }
        if (days == 1) {
          return (
            label: 'Allotment expected tomorrow',
            icon: Icons.schedule_rounded,
            color: AppColors.amber,
          );
        }
        if (days > 1) {
          return (
            label:
                'Allotment ${Formatters.relativeDay(allotment, capitalize: false)}',
            icon: Icons.schedule_rounded,
            color: AppColors.amber,
          );
        }
        return (
          label: 'Ready for allotment check',
          icon: Icons.fact_check_outlined,
          color: AppColors.brand,
        );
      }
    }

    return switch (status) {
      ApplicationStatus.waiting => (
        label: 'Waiting for allotment date',
        icon: Icons.schedule_rounded,
        color: AppColors.amber,
      ),
      ApplicationStatus.checking => (
        label: 'Checking allotment',
        icon: Icons.sync_rounded,
        color: AppColors.brand,
      ),
      ApplicationStatus.allotted => (
        label: 'Allotted',
        icon: Icons.celebration_rounded,
        color: AppColors.mint,
      ),
      ApplicationStatus.notAllotted => (
        label: 'Not allotted',
        icon: Icons.remove_circle_outline_rounded,
        color: Colors.blueGrey,
      ),
      ApplicationStatus.noRecord => (
        label: 'No allotment record found',
        icon: Icons.search_off_rounded,
        color: AppColors.rose,
      ),
      ApplicationStatus.resultNotLive => (
        label: 'Result not live yet',
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.amber,
      ),
      ApplicationStatus.humanRequired => (
        label: 'Manual verification required',
        icon: Icons.touch_app_rounded,
        color: AppColors.rose,
      ),
      ApplicationStatus.temporaryError => (
        label: 'Temporary issue — try again',
        icon: Icons.error_outline_rounded,
        color: AppColors.rose,
      ),
      ApplicationStatus.unsupportedRegistrar => (
        label: 'Registrar checker not supported yet',
        icon: Icons.extension_off_outlined,
        color: Colors.blueGrey,
      ),
      ApplicationStatus.unknown => (
        label: 'Result needs another check',
        icon: Icons.help_outline_rounded,
        color: AppColors.amber,
      ),
    };
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.helper,
    this.end = false,
  });

  final String label;
  final String value;
  final String? helper;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end
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
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (helper != null) ...[
          const SizedBox(height: 2),
          Text(
            helper!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ],
    );
  }
}

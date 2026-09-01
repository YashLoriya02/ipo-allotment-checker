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
  });

  final IpoApplication application;
  final Ipo ipo;
  final PanProfile? profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _stateVisual(application.status);

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
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    Formatters.initials(ipo.name),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ipo.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${ipo.typeLabel} • ${profile?.name ?? 'PAN profile'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove from Applied')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: state.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(state.icon, color: state.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.label,
                      style: TextStyle(color: state.color, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _Meta(label: 'Allotment', value: Formatters.shortDate(ipo.allotmentDate))),
                Expanded(child: _Meta(label: 'Registrar', value: ipo.registrarCode ?? '—')),
                Expanded(child: _Meta(label: 'PAN', value: profile?.maskedPan ?? 'Removed', end: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({String label, IconData icon, Color color}) _stateVisual(ApplicationStatus status) => switch (status) {
        ApplicationStatus.waiting => (label: 'Waiting for allotment', icon: Icons.schedule_rounded, color: AppColors.amber),
        ApplicationStatus.checking => (label: 'Checking allotment', icon: Icons.sync_rounded, color: AppColors.brand),
        ApplicationStatus.allotted => (label: 'Allotted', icon: Icons.celebration_rounded, color: AppColors.mint),
        ApplicationStatus.notAllotted => (label: 'Not allotted', icon: Icons.remove_circle_outline_rounded, color: Colors.blueGrey),
        ApplicationStatus.resultNotLive => (label: 'Result not live yet', icon: Icons.hourglass_bottom_rounded, color: AppColors.amber),
        ApplicationStatus.humanRequired => (label: 'Manual verification required', icon: Icons.touch_app_rounded, color: AppColors.rose),
        ApplicationStatus.error => (label: 'Temporary issue', icon: Icons.error_outline_rounded, color: AppColors.rose),
      };
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.end = false});
  final String label;
  final String value;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

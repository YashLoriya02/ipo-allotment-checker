import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/ipo.dart';
import '../../../data/models/pan_profile.dart';
import '../../applied/controllers/applied_controller.dart';
import '../../profile/controllers/profile_controller.dart';

class ApplyIpoDialog extends StatefulWidget {
  const ApplyIpoDialog({super.key, required this.ipo});

  final Ipo ipo;

  @override
  State<ApplyIpoDialog> createState() => _ApplyIpoDialogState();
}

class _ApplyIpoDialogState extends State<ApplyIpoDialog> {
  String? _selectedProfileId;
  bool _saving = false;

  ProfileController get _profiles => Get.find<ProfileController>();
  AppliedController get _applications => Get.find<AppliedController>();

  PanProfile? _effectiveSelection(List<PanProfile> available) {
    if (available.isEmpty) return null;

    final explicitlySelected = available.firstWhereOrNull(
      (profile) => profile.id == _selectedProfileId,
    );
    if (explicitlySelected != null) return explicitlySelected;

    final defaultProfile = _profiles.defaultProfile;
    if (defaultProfile != null &&
        available.any((profile) => profile.id == defaultProfile.id)) {
      return defaultProfile;
    }

    return available.first;
  }

  Future<void> _save(PanProfile profile) async {
    if (_saving) return;
    setState(() => _saving = true);

    final added = await _applications.addApplication(widget.ipo, profile);
    if (!mounted) return;

    if (added) {
      Get.back();
      return;
    }

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Obx(() {
            final profiles = _profiles.profiles.toList();
            final available = profiles
                .where(
                  (profile) => !_applications.isAppliedWithProfile(
                    widget.ipo.id,
                    profile.id,
                  ),
                )
                .toList();
            final selected = _effectiveSelection(available);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.bookmark_add_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add application',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.ipo.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => Get.back(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IpoSummary(ipo: widget.ipo),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Applied using',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _profiles.openAddProfileSheet,
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('Add PAN'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (profiles.isEmpty)
                          _NoPanProfile(onAdd: _profiles.openAddProfileSheet)
                        else ...[
                          ...profiles.map((profile) {
                            final alreadyAdded = _applications.isAppliedWithProfile(
                              widget.ipo.id,
                              profile.id,
                            );
                            final isSelected = selected?.id == profile.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: InkWell(
                                onTap: alreadyAdded
                                    ? null
                                    : () => setState(
                                          () => _selectedProfileId = profile.id,
                                        ),
                                borderRadius: BorderRadius.circular(17),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary.withValues(alpha: 0.42)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    profile.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                                if (profile.isDefault) ...[
                                                  const SizedBox(width: 7),
                                                  const Text(
                                                    'DEFAULT',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color: AppColors.mint,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              alreadyAdded
                                                  ? '${profile.maskedPan} · Already added'
                                                  : profile.maskedPan,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (alreadyAdded)
                                        const Icon(Icons.check_circle_rounded, color: AppColors.mint)
                                      else
                                        Radio<String>(
                                          value: profile.id,
                                          groupValue: selected?.id,
                                          onChanged: (value) => setState(
                                            () => _selectedProfileId = value,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: selected == null || _saving
                              ? null
                              : () => _save(selected),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            available.isEmpty && profiles.isNotEmpty
                                ? 'All PAN profiles already added'
                                : _saving
                                    ? 'Adding…'
                                    : 'Add to My Applications',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _IpoSummary extends StatelessWidget {
  const _IpoSummary({required this.ipo});
  final Ipo ipo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: 'Allotment',
              value: ipo.allotmentDate == null
                  ? 'Pending'
                  : Formatters.relativeDay(ipo.allotmentDate),
              helper: Formatters.shortDate(ipo.allotmentDate),
            ),
          ),
          Expanded(
            child: _SummaryValue(
              label: 'Registrar',
              value: ipo.registrarCode ?? 'Pending',
              helper: ipo.typeLabel,
              end: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.helper,
    this.end = false,
  });

  final String label;
  final String value;
  final String helper;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(
          helper,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NoPanProfile extends StatelessWidget {
  const _NoPanProfile({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Icon(Icons.badge_outlined, size: 30),
          const SizedBox(height: 8),
          const Text('Add a PAN profile first', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            'Save the PAN once, then reuse the profile for future IPO applications.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add PAN profile'),
          ),
        ],
      ),
    );
  }
}

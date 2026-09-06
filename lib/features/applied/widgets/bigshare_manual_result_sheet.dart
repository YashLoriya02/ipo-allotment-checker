import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/models/ipo.dart';

enum BigshareManualOutcome { allotted, notAllotted }

class BigshareManualStatusUpdate {
  const BigshareManualStatusUpdate({
    required this.outcome,
    this.allottedShares,
  });

  final BigshareManualOutcome outcome;
  final int? allottedShares;
}

class BigshareManualResultSheet extends StatefulWidget {
  const BigshareManualResultSheet({
    super.key,
    required this.ipo,
    required this.profileName,
  });

  final Ipo ipo;
  final String profileName;

  @override
  State<BigshareManualResultSheet> createState() =>
      _BigshareManualResultSheetState();
}

class _BigshareManualResultSheetState
    extends State<BigshareManualResultSheet> {
  final TextEditingController _sharesController = TextEditingController();
  BigshareManualOutcome? _selected;

  @override
  void dispose() {
    _sharesController.dispose();
    super.dispose();
  }

  void _save() {
    final selected = _selected;
    if (selected == null) return;

    final shares = selected == BigshareManualOutcome.allotted
        ? int.tryParse(_sharesController.text.trim())
        : null;

    Get.back(
      result: BigshareManualStatusUpdate(
        outcome: selected,
        allottedShares: shares != null && shares > 0 ? shares : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.fact_check_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update allotment status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'What result did Bigshare show?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ipo.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.profileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OutcomeTile(
                    icon: Icons.celebration_rounded,
                    title: 'Allotted',
                    subtitle: 'Bigshare showed that shares were allotted.',
                    selected: _selected == BigshareManualOutcome.allotted,
                    onTap: () => setState(
                      () => _selected = BigshareManualOutcome.allotted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _OutcomeTile(
                    icon: Icons.cancel_outlined,
                    title: 'Not allotted',
                    subtitle: 'Bigshare showed zero allotted shares.',
                    selected: _selected == BigshareManualOutcome.notAllotted,
                    onTap: () => setState(
                      () => _selected = BigshareManualOutcome.notAllotted,
                    ),
                  ),
                  if (_selected == BigshareManualOutcome.allotted) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _sharesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Shares allotted (optional)',
                        hintText: 'e.g. 182',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Keep pending'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _selected == null ? null : _save,
                          child: const Text('Save status'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      'This status is saved only in your IPO tracker.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.09)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary.withValues(alpha: 0.45) : theme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? primary : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? primary : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

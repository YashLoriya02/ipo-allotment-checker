import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/pan_profile.dart';
import '../controllers/backup_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/theme_controller.dart';
import 'debug_notification_test_view.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final backupController = Get.find<BackupController>();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'PAN profiles, appearance and app preferences.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionCard(
                title: 'PAN profiles',
                subtitle: 'Saved securely on this device',
                trailing: TextButton.icon(
                  onPressed: controller.openAddProfileSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
                child: Obx(() {
                  if (controller.profiles.isEmpty) {
                    return _PanEmpty(onAdd: controller.openAddProfileSheet);
                  }

                  final items = [...controller.profiles]
                    ..sort((a, b) {
                      if (a.isDefault == b.isDefault) return 0;
                      return a.isDefault ? -1 : 1;
                    });

                  return Column(
                    children: items
                        .map(
                          (profile) => _PanTile(
                            profile: profile,
                            controller: controller,
                          ),
                        )
                        .toList(),
                  );
                }),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Appearance',
                child: Obx(
                  () => Column(
                    children: [
                      _ThemeTile(
                        label: 'System',
                        icon: Icons.brightness_auto_rounded,
                        selected:
                            themeController.themeMode.value == ThemeMode.system,
                        onTap: () => themeController.setMode(ThemeMode.system),
                      ),
                      _ThemeTile(
                        label: 'Light',
                        icon: Icons.light_mode_rounded,
                        selected:
                            themeController.themeMode.value == ThemeMode.light,
                        onTap: () => themeController.setMode(ThemeMode.light),
                      ),
                      _ThemeTile(
                        label: 'Dark',
                        icon: Icons.dark_mode_rounded,
                        selected:
                            themeController.themeMode.value == ThemeMode.dark,
                        onTap: () => themeController.setMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _BackupCard(controller: backupController),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'IPO data',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.mint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.cloud_done_outlined,
                      color: AppColors.mint,
                    ),
                  ),
                  title: const Text(
                    'Upstox IPO API',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Open, upcoming, closed and listed IPO data with local offline cache.',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.mint,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Developer tools',
                  subtitle: 'Visible in debug builds only',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Notification trigger tester',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Send an IPO Premium-style notification from this app.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Get.to<void>(() => const DebugNotificationTestView()),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const _SecurityNote(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.controller});

  final BackupController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Backup & restore',
      subtitle: 'Move all your data between app installations',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.amber,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exported backups contain full PAN numbers in readable '
                    'text. Store and share them securely.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Obx(() {
            final isExporting = controller.isExporting.value;
            final isBusy = isExporting || controller.isImporting.value;

            return Builder(
              builder: (buttonContext) => ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !isBusy,
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text(
                  'Export backup',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Applications, PAN profiles, IPO cache and preferences',
                ),
                trailing: isExporting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => _confirmExport(buttonContext),
              ),
            );
          }),
          const Divider(height: 1),
          Obx(
            () => ListTile(
              contentPadding: EdgeInsets.zero,
              enabled:
                  !controller.isImporting.value &&
                  !controller.isExporting.value,
              leading: const Icon(Icons.download_rounded),
              title: const Text(
                'Import backup',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Replaces all data currently in this app'),
              trailing: controller.isImporting.value
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickAndConfirmImport(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExport(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final shareOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.lock_open_rounded, color: AppColors.amber),
        title: const Text('Export unencrypted PANs?'),
        content: const Text(
          'The backup file will include every full PAN in readable text so it '
          'can be restored after reinstalling the app. Anyone with the file '
          'can read those PANs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.exportBackup(sharePositionOrigin: shareOrigin);
    }
  }

  Future<void> _pickAndConfirmImport(BuildContext context) async {
    final backup = await controller.pickBackup();
    if (backup == null || !context.mounted) return;

    final exported = backup.exportedAt.toLocal();
    final exportedLabel =
        '${exported.day.toString().padLeft(2, '0')}/'
        '${exported.month.toString().padLeft(2, '0')}/${exported.year}';
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.restore_rounded, color: AppColors.amber),
        title: const Text('Replace current app data?'),
        content: Text(
          'Backup from $exportedLabel contains ${backup.profiles.length} PAN '
          '${backup.profiles.length == 1 ? 'profile' : 'profiles'} and '
          '${backup.applications.length} '
          '${backup.applications.length == 1 ? 'application' : 'applications'}.\n\n'
          'Importing replaces all data currently stored in this app. The '
          'backup contains full PAN numbers in readable text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Replace & restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.restoreBackup(backup);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PanTile extends StatelessWidget {
  const _PanTile({required this.profile, required this.controller});

  final PanProfile profile;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final usage = controller.usageCount(profile.id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.10),
        child: Icon(
          Icons.person_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (profile.isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'DEFAULT',
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.mint,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        usage > 0
            ? '${profile.maskedPan} · $usage ${usage == 1 ? 'application' : 'applications'}'
            : profile.maskedPan,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'PAN profile options',
        onSelected: (value) {
          if (value == 'edit') _showEditDialog(context);
          if (value == 'default') controller.setDefault(profile.id);
          if (value == 'delete') _showDeleteDialog(context);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 19),
                SizedBox(width: 10),
                Text('Edit label'),
              ],
            ),
          ),
          if (!profile.isDefault)
            const PopupMenuItem(
              value: 'default',
              child: Row(
                children: [
                  Icon(Icons.star_outline_rounded, size: 19),
                  SizedBox(width: 10),
                  Text('Make default'),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 19),
                SizedBox(width: 10),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final textController = TextEditingController(text: profile.name);
    String? error;

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit profile label'),
          content: TextField(
            controller: textController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Profile name',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final result = await controller.renameProfile(
                  profile,
                  textController.text,
                );
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
                Get.back();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    textController.dispose();
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final active = controller.activeUsageCount(profile.id);
    final total = controller.usageCount(profile.id);

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
        title: const Text('Delete PAN profile?'),
        content: Text(
          active > 0
              ? 'This PAN is used by $active active ${active == 1 ? 'application' : 'applications'}. The applications will remain, but automatic checking cannot use this PAN after deletion.'
              : total > 0
              ? 'This PAN is referenced by $total saved ${total == 1 ? 'application' : 'applications'}. The application history will remain, but the PAN will be removed.'
              : 'The full PAN will be removed from secure storage on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteProfile(profile);
    }
  }
}

class _PanEmpty extends StatelessWidget {
  const _PanEmpty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.badge_outlined, size: 30),
          const SizedBox(height: 9),
          const Text(
            'No PAN profile yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Add it once, then simply select the profile whenever you apply to an IPO.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAdd,
            child: const Text('Add PAN profile'),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.circle_outlined),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.mint),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAN stays private',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'The full PAN is stored in platform secure storage. Normal app data only keeps the masked PAN and profile ID.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

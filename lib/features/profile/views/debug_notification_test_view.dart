import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/ipo_premium_notification_listener_service.dart';
import '../../../data/services/local_notification_service.dart';

/// Development-only page for exercising the real Android notification
/// listener without waiting for IPO Premium to publish a notification.
class DebugNotificationTestView extends StatefulWidget {
  const DebugNotificationTestView({super.key});

  @override
  State<DebugNotificationTestView> createState() =>
      _DebugNotificationTestViewState();
}

class _DebugNotificationTestViewState extends State<DebugNotificationTestView> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: '📣 Milky Mist Dairy Food Ltd. (Mainboard)',
    );
    _messageController = TextEditingController(
      text: 'Allotment is Out at 08:10 PM\nClick here to check allotment',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!kDebugMode || _sending) return;

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      Get.snackbar(
        'Missing notification content',
        'Enter both a title and a message.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await LocalNotificationService.instance.showDebugTriggerNotification(
        title: title,
        message: message,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final listener = IpoPremiumNotificationListenerService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification trigger tester')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How this test works',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This posts a real notification from this app. In debug '
                    'mode only, the IPO listener accepts this app package as '
                    'a test source and runs the same allotment filtering and '
                    'matching logic used for IPO Premium.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Obx(() {
              final access = listener.hasNotificationAccess.value;
              final running = listener.listenerRunning.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  access && running
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                ),
                title: Text(
                  access && running
                      ? 'Notification listener ready'
                      : 'Notification access required',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  access
                      ? (running
                            ? 'Listener is running.'
                            : 'Access granted; listener is not running.')
                      : 'Enable notification access before sending the test.',
                ),
                trailing: access
                    ? IconButton(
                        tooltip: 'Refresh',
                        onPressed: listener.refreshAndStartIfAllowed,
                        icon: const Icon(Icons.refresh_rounded),
                      )
                    : TextButton(
                        onPressed: listener.openNotificationAccessSettings,
                        child: const Text('Enable'),
                      ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notification title',
                hintText: '📣 Milky Mist Dairy Food Ltd. (Mainboard)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notification message',
                hintText:
                    'Allotment is Out at 08:10 PM\nClick here to check allotment',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending…' : 'Send test notification'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'For a full KFin test, keep a supported IPO such as Milky Mist '
              'active in Applied. You can also type any IPO Premium-style '
              'notification here to test only the trigger/matching behavior.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

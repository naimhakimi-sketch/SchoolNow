import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

class NotificationSimulatorPage extends StatelessWidget {
  final String parentId;
  final String childId;
  final String childName;

  const NotificationSimulatorPage({
    super.key,
    required this.parentId,
    required this.childId,
    required this.childName,
  });

  Future<void> _create(
    BuildContext context, {
    required String type,
    required String message,
  }) async {
    final notifications = NotificationService();
    final id = 'sim_${type}_${DateTime.now().millisecondsSinceEpoch}';

    await notifications.createUnique(
      notificationId: id,
      userId: parentId,
      type: type,
      message: message,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notification created.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Simulator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create sample notifications for testing.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _create(
                context,
                type: 'boarding',
                message: '$childName: Boarding status changed',
              ),
              child: const Text('Simulate Status Change'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _create(
                context,
                type: 'billing',
                message: 'Payment due in 2 day(s) for $childName',
              ),
              child: const Text('Simulate Payment Reminder (2 days)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _create(
                context,
                type: 'billing',
                message: 'Payment due in 1 day(s) for $childName',
              ),
              child: const Text('Simulate Payment Reminder (1 day)'),
            ),
            const SizedBox(height: 12),
            Text(
              'These will appear in the notifications list on the Profile page.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

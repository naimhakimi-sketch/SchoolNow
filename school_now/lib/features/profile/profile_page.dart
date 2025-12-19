import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/parent_service.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  final String parentId;
  final QueryDocumentSnapshot<Map<String, dynamic>> childDoc;

  const ProfilePage({
    super.key,
    required this.parentId,
    required this.childDoc,
  });

  @override
  Widget build(BuildContext context) {
    final auth = ParentAuthService();
    final parentService = ParentService();
    final notificationService = NotificationService();
    final child = childDoc.data();
    final assignedDriver = (child['assigned_driver_id'] ?? '').toString();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: parentService.streamParent(parentId),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name = (data['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? '').toString();
        final email = (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();
        final contact = (data['contact_number'] ?? '').toString();
        final address = (data['address'] ?? '').toString();

        final notif = (data['notifications'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final proximityAlert = (notif['proximity_alert'] as bool?) ?? true;
        final boardingAlert = (notif['boarding_alert'] as bool?) ?? true;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: Text('Profile', style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(
                          parentId: parentId,
                          name: name,
                          contactNumber: contact,
                          address: address,
                          addressLocked: assignedDriver.isNotEmpty,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(title: const Text('Name'), subtitle: Text(name)),
            ListTile(title: const Text('Email'), subtitle: Text(email)),
            if (contact.isNotEmpty) ListTile(title: const Text('Contact'), subtitle: Text(contact)),
            ListTile(
              title: const Text('Address'),
              subtitle: Text(address.isEmpty ? '(not set)' : address),
              trailing: assignedDriver.isNotEmpty ? const Text('Locked') : null,
            ),
            const SizedBox(height: 12),
            Text('Student QR (for offline use):', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(child: QrImageView(data: childDoc.id, size: 160)),

            const SizedBox(height: 18),
            Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Proximity alerts'),
                    subtitle: const Text('Notify when driver is near pickup'),
                    value: proximityAlert,
                    onChanged: (v) {
                      parentService.updateParent(parentId, {
                        'notifications': {
                          'proximity_alert': v,
                          'boarding_alert': boardingAlert,
                        },
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Boarding status alerts'),
                    subtitle: const Text('Notify when boarding status changes'),
                    value: boardingAlert,
                    onChanged: (v) {
                      parentService.updateParent(parentId, {
                        'notifications': {
                          'proximity_alert': proximityAlert,
                          'boarding_alert': v,
                        },
                      });
                    },
                  ),
                ],
              ),
            ),

            if (assignedDriver.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Billing', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('payments')
                    .where('parent_id', isEqualTo: parentId)
                    .snapshots(),
                builder: (context, paySnap) {
                  final docs = (paySnap.data as dynamic)?.docs as List?;
                  if (docs == null) return const SizedBox.shrink();

                  // Filter client-side to avoid composite index requirements.
                  final filtered = docs.where((d) {
                    final m = (d.data() as Map).cast<String, dynamic>();
                    return (m['child_id'] ?? '').toString() == childDoc.id &&
                        (m['driver_id'] ?? '').toString() == assignedDriver;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Text('No payment record yet.');
                  }

                  filtered.sort((a, b) {
                    final ma = (a.data() as Map).cast<String, dynamic>();
                    final mb = (b.data() as Map).cast<String, dynamic>();
                    final ta = (ma['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final tb = (mb['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return tb.compareTo(ta);
                  });

                  final latest = filtered.first;
                  final m = (latest.data() as Map).cast<String, dynamic>();
                  final status = (m['status'] ?? 'pending').toString();
                  final createdAt = (m['created_at'] as Timestamp?)?.toDate();

                  DateTime? due;
                  if (createdAt != null) {
                    due = createdAt.add(const Duration(days: 30));
                  }

                  String? dueText;
                  int? daysLeft;
                  if (due != null) {
                    final now = DateTime.now();
                    daysLeft = due.difference(DateTime(now.year, now.month, now.day)).inDays;
                    dueText = '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';

                    // SRS FR-PA-5.8: reminders 2 days and 1 day before due date.
                    if ((daysLeft == 2 || daysLeft == 1) && status != 'pending') {
                      final notifId = 'billing_${childDoc.id}_${dueText}_${daysLeft}d';
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        notificationService.createUnique(
                          notificationId: notifId,
                          userId: parentId,
                          type: 'billing',
                          message: 'Payment due in $daysLeft day(s) for ${(child['child_name'] ?? 'child').toString()}',
                        );
                      });
                    }
                  }

                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Latest payment status'),
                          subtitle: Text(status),
                        ),
                        if (dueText != null)
                          ListTile(
                            title: const Text('Next due date'),
                            subtitle: Text(dueText),
                            trailing: (daysLeft != null && daysLeft >= 0 && daysLeft <= 5)
                                ? Text('$daysLeft days')
                                : null,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 12),
            StreamBuilder(
              stream: notificationService.streamForUser(parentId),
              builder: (context, notifSnap) {
                final docs = (notifSnap.data as dynamic)?.docs as List?;
                if (docs == null) return const SizedBox.shrink();
                if (docs.isEmpty) {
                  return const Text('No notifications yet.');
                }
                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final m = (d.data() as Map).cast<String, dynamic>();
                      final type = (m['type'] ?? '').toString();
                      final message = (m['message'] ?? '').toString();
                      final read = (m['read'] == true);
                      return ListTile(
                        title: Text(message.isEmpty ? '(no message)' : message),
                        subtitle: type.isEmpty ? null : Text(type),
                        trailing: read ? null : const Icon(Icons.circle, size: 10),
                        onTap: () => notificationService.markRead(d.id),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/parent_service.dart';
import '../children/add_child_page.dart';
import '../children/edit_child_page.dart';
import 'edit_profile_page.dart';
import 'notification_simulator_page.dart';

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

    final childRef = parentService.childrenRef(parentId).doc(childDoc.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: parentService.streamParent(parentId),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name =
            (data['name'] ??
                    FirebaseAuth.instance.currentUser?.displayName ??
                    '')
                .toString();
        final email =
            (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
                .toString();
        final contact = (data['contact_number'] ?? '').toString();
        final address = (data['address'] ?? '').toString();

        final notif =
            (data['notifications'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final proximityAlert = (notif['proximity_alert'] as bool?) ?? true;
        final boardingAlert = (notif['boarding_alert'] as bool?) ?? true;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: childRef.snapshots(),
          builder: (context, childSnap) {
            final child = childSnap.data?.data() ?? childDoc.data();
            final assignedDriver = (child['assigned_driver_id'] ?? '')
                .toString();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
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
                if (contact.isNotEmpty)
                  ListTile(
                    title: const Text('Contact'),
                    subtitle: Text(contact),
                  ),
                ListTile(
                  title: const Text('Address'),
                  subtitle: Text(address.isEmpty ? '(not set)' : address),
                  trailing: assignedDriver.isNotEmpty
                      ? const Text('Locked')
                      : null,
                ),
                const SizedBox(height: 12),
                Text('Student', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: Text(
                          (child['child_name'] ?? 'Student').toString(),
                        ),
                        subtitle: Text(
                          [
                            if (((child['child_ic'] ?? '').toString())
                                .trim()
                                .isNotEmpty)
                              'IC: ${(child['child_ic'] ?? '').toString()}',
                            if (((child['school_name'] ?? '').toString())
                                .trim()
                                .isNotEmpty)
                              'School: ${(child['school_name'] ?? '').toString()}',
                          ].whereType<String>().join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditChildPage(
                                parentId: parentId,
                                childId: childDoc.id,
                                initialChildName: (child['child_name'] ?? '')
                                    .toString(),
                                initialChildIc: (child['child_ic'] ?? '')
                                    .toString(),
                                initialSchoolName: (child['school_name'] ?? '')
                                    .toString(),
                                initialSchoolId: child['school_id']?.toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddChildPage()),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Another Child'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Student QR (for offline use):',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Center(child: QrImageView(data: childDoc.id, size: 160)),

                const SizedBox(height: 18),
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notification Simulator'),
                    subtitle: const Text(
                      'Create sample notifications for testing',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationSimulatorPage(
                            parentId: parentId,
                            childId: childDoc.id,
                            childName: (child['child_name'] ?? 'child')
                                .toString(),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Proximity alerts'),
                        subtitle: const Text(
                          'Notify when driver is near pickup',
                        ),
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
                        subtitle: const Text(
                          'Notify when boarding status changes',
                        ),
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
                  Text(
                    'Billing',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                        return (m['child_id'] ?? '').toString() ==
                                childDoc.id &&
                            (m['driver_id'] ?? '').toString() == assignedDriver;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Text('No payment record yet.');
                      }

                      filtered.sort((a, b) {
                        final ma = (a.data() as Map).cast<String, dynamic>();
                        final mb = (b.data() as Map).cast<String, dynamic>();
                        final ta =
                            (ma['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb =
                            (mb['created_at'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });

                      final latest = filtered.first;
                      final m = (latest.data() as Map).cast<String, dynamic>();
                      final status = (m['status'] ?? 'pending').toString();
                      final amount = (m['amount'] ?? 0).toString();
                      final metadata =
                          (m['metadata'] as Map?)?.cast<String, dynamic>() ??
                          {};
                      final cardLast4 =
                          (metadata['card_last4'] ?? (m['card_last4'] ?? ''))
                              .toString();
                      final method = (metadata['method'] ?? (m['method'] ?? ''))
                          .toString();
                      final nameOnCard =
                          (metadata['name_on_card'] ??
                                  (m['name_on_card'] ?? ''))
                              .toString();
                      final createdAt = (m['created_at'] as Timestamp?)
                          ?.toDate();

                      // Calculate due date: 1st of next month
                      DateTime? dueDate;
                      if (createdAt != null) {
                        final nextMonth = createdAt.month == 12
                            ? DateTime(createdAt.year + 1, 1, 1)
                            : DateTime(createdAt.year, createdAt.month + 1, 1);
                        dueDate = nextMonth;
                      }

                      String? dueText;
                      int? daysLeft;
                      if (dueDate != null) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        daysLeft = dueDate.difference(today).inDays;
                        dueText =
                            '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

                        // SRS FR-PA-5.8: reminders 2 days and 1 day before due date.
                        if ((daysLeft == 2 || daysLeft == 1) &&
                            status == 'pending') {
                          final notifId =
                              'billing_${childDoc.id}_${dueText}_${daysLeft}d';
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            notificationService.createUnique(
                              notificationId: notifId,
                              userId: parentId,
                              type: 'billing',
                              message:
                                  'Payment due in $daysLeft day(s) for ${(child['child_name'] ?? 'child').toString()}',
                            );
                          });
                        }
                      }

                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Payment Status'),
                              subtitle: Text(status),
                              trailing: status == 'completed'
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                    )
                                  : null,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Amount'),
                              subtitle: Text('RM $amount'),
                            ),
                            const Divider(height: 1),
                            if (method.isNotEmpty)
                              ListTile(
                                title: const Text('Payment Method'),
                                subtitle: Text(method),
                              ),
                            if (method.isNotEmpty) const Divider(height: 1),
                            if (cardLast4.isNotEmpty)
                              ListTile(
                                title: const Text('Card Last 4'),
                                subtitle: Text(cardLast4),
                              ),
                            if (cardLast4.isNotEmpty) const Divider(height: 1),
                            if (nameOnCard.isNotEmpty)
                              ListTile(
                                title: const Text('Name on Card'),
                                subtitle: Text(nameOnCard),
                              ),
                            if (nameOnCard.isNotEmpty) const Divider(height: 1),
                            ListTile(
                              title: const Text('Last Payment Date'),
                              subtitle: Text(
                                createdAt == null
                                    ? 'N/A'
                                    : '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                            const Divider(height: 1),
                            if (dueText != null)
                              ListTile(
                                title: const Text('Next Payment Due'),
                                subtitle: Text(dueText),
                                trailing:
                                    (daysLeft != null &&
                                        daysLeft <= 7 &&
                                        daysLeft > 0)
                                    ? Text(
                                        '$daysLeft days left',
                                        style: TextStyle(
                                          color: daysLeft <= 2
                                              ? Colors.red
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : (daysLeft != null && daysLeft <= 0)
                                    ? const Text(
                                        'Overdue',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            const Divider(height: 1),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('parents')
                                  .doc(parentId)
                                  .collection('children')
                                  .doc(childDoc.id)
                                  .snapshots(),
                              builder: (context, childSnap) {
                                final childData = childSnap.data?.data() ?? {};
                                final serviceEndDate =
                                    (childData['service_end_date']
                                            as Timestamp?)
                                        ?.toDate();
                                if (serviceEndDate == null) {
                                  return const SizedBox.shrink();
                                }
                                final serviceEndText =
                                    '${serviceEndDate.year.toString().padLeft(4, '0')}-${serviceEndDate.month.toString().padLeft(2, '0')}-${serviceEndDate.day.toString().padLeft(2, '0')}';
                                final now = DateTime.now();
                                final today = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final daysUntilExpiry = serviceEndDate
                                    .difference(today)
                                    .inDays;
                                return ListTile(
                                  title: const Text('Service End Date'),
                                  subtitle: Text(serviceEndText),
                                  trailing:
                                      daysUntilExpiry <= 7 &&
                                          daysUntilExpiry > 0
                                      ? Text(
                                          '$daysUntilExpiry days left',
                                          style: TextStyle(
                                            color: daysUntilExpiry <= 2
                                                ? Colors.red
                                                : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : daysUntilExpiry <= 0
                                      ? const Text(
                                          'Expired',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                );
                              },
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
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final m = (d.data() as Map).cast<String, dynamic>();
                          final type = (m['type'] ?? '').toString();
                          final message = (m['message'] ?? '').toString();
                          final read = (m['read'] == true);
                          return ListTile(
                            title: Text(
                              message.isEmpty ? '(no message)' : message,
                            ),
                            subtitle: type.isEmpty ? null : Text(type),
                            trailing: read
                                ? null
                                : const Icon(Icons.circle, size: 10),
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
      },
    );
  }
}

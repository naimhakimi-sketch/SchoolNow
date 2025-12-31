import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/parent_service.dart';

class ManageParentsScreen extends StatelessWidget {
  const ManageParentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ParentService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Parents'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getParents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No parents registered yet',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] ?? 'Unnamed';
              final email = data['email'] ?? '';
              final contact = data['contact_number'] ?? '';
              final address = data['address'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: Colors.purple),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty) Text('📧 $email'),
                      if (contact.isNotEmpty) Text('📞 $contact'),
                      if (address.isNotEmpty)
                        Text(
                          '📍 $address',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                        ),
                        onPressed: () =>
                            _showParentDetails(context, doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, doc.id, name),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showParentDetails(
    BuildContext context,
    String parentId,
    Map<String, dynamic> data,
  ) async {
    final service = ParentService();
    final children = await service.getParentChildren(parentId);
    final paymentCount = await service.getParentPaymentCount(parentId);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(data['name'] ?? 'Parent Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('IC Number', data['ic_number'] ?? 'N/A'),
              _detailRow('Email', data['email'] ?? 'N/A'),
              _detailRow('Contact', data['contact_number'] ?? 'N/A'),
              _detailRow('Address', data['address'] ?? 'N/A'),
              const Divider(height: 24),
              const Text(
                'Children:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (children.isEmpty)
                const Text(
                  'No children registered',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${child['child_name'] ?? 'Unnamed Child'}'),
                  ),
                ),
              const Divider(height: 24),
              _detailRow('Total Payments', paymentCount.toString()),
              const SizedBox(height: 8),
              // Notifications settings
              if (data['notifications'] != null) ...[
                const Text(
                  'Notifications:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Proximity Alerts',
                  data['notifications']['proximity_alert'] == true
                      ? 'Enabled'
                      : 'Disabled',
                ),
                _detailRow(
                  'Boarding Alerts',
                  data['notifications']['boarding_alert'] == true
                      ? 'Enabled'
                      : 'Disabled',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String parentId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Parent'),
        content: Text(
          'Are you sure you want to delete parent "$name"? This will also delete all their children and related data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ParentService().deleteParent(parentId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Parent deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

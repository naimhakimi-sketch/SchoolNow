import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_driver_service.dart';
import 'driver_form_screen.dart';

class ManageDriversScreen extends StatelessWidget {
  const ManageDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminDriverService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Drivers'), centerTitle: true),
      // Removed floatingActionButton for adding drivers
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getDrivers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No drivers registered yet',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;

              final name = d['name'] ?? 'Unnamed';
              final email = d['email'] ?? '';
              final contact = d['contact_number'] ?? '';
              final isVerified = d['is_verified'] == true;
              final monthlyFee = d['monthly_fee'] ?? 0;

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
                    backgroundColor: isVerified
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    child: Icon(
                      isVerified ? Icons.verified : Icons.pending,
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isVerified)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty) Text('📧 $email'),
                      if (contact.isNotEmpty) Text('📞 $contact'),
                      if (monthlyFee > 0)
                        Text('💰 RM ${monthlyFee.toStringAsFixed(2)}/month'),
                    ],
                  ),
                  trailing: Switch(
                    value: isVerified,
                    onChanged: (v) async {
                      // Check if all required fields are filled before verification
                      if (v) {
                        final missingFields = <String>[];
                        if (d['monthly_fee'] == null || d['monthly_fee'] == 0) {
                          missingFields.add('Monthly Fee');
                        }
                        if (d['service_area'] == null) {
                          missingFields.add('Service Area');
                        }
                        // Check for multiple schools
                        final schoolIds = d['assigned_school_ids'] ?? [];
                        if (schoolIds.isEmpty) {
                          missingFields.add('Assigned School(s)');
                        }
                        if (d['assigned_bus_id'] == null ||
                            (d['assigned_bus_id'] as String).isEmpty) {
                          missingFields.add('Assigned Bus');
                        }

                        if (missingFields.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot verify. Missing: ${missingFields.join(', ')}',
                              ),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      }

                      await service.updateDriver(doc.id, {
                        'is_verified': v,
                        'is_searchable': v,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              v ? 'Driver verified' : 'Driver unverified',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () => _openDriverPanel(context, doc.id, d),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDriverPanel(
    BuildContext context,
    String id,
    Map<String, dynamic> d,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DriverPanel(driverId: id, data: d),
    );
  }
}

class _DriverPanel extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> data;

  const _DriverPanel({required this.driverId, required this.data});

  @override
  Widget build(BuildContext context) {
    final service = AdminDriverService();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Driver Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          // Display all driver information
          _infoRow('Name', data['name'] ?? 'N/A'),
          _infoRow('IC Number', data['ic_number'] ?? 'N/A'),
          _infoRow('Email', data['email'] ?? 'N/A'),
          _infoRow('Contact', data['contact_number'] ?? 'N/A'),
          _infoRow('License Number', data['license_number'] ?? 'N/A'),
          _infoRow(
            'Monthly Fee',
            'RM ${data['monthly_fee']?.toString() ?? '0'}',
          ),
          _infoRow('Assigned Bus', data['assigned_bus_id'] ?? 'Not assigned'),

          if (data['service_area'] != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Service Area:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _infoRow('School', data['service_area']['school_name'] ?? 'N/A'),
            _infoRow('Side', data['service_area']['side'] ?? 'N/A'),
            _infoRow('Radius', '${data['service_area']['radius_km'] ?? 0} km'),
          ],

          const SizedBox(height: 12),
          _infoRow(
            'Verification',
            data['is_verified'] == true ? '✅ Verified' : '⏳ Pending',
          ),
          _infoRow('Searchable', data['is_searchable'] == true ? 'Yes' : 'No'),

          const SizedBox(height: 24),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverFormScreen(
                          driverId: driverId,
                          initialData: data,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: data['is_verified'] == true
                        ? Colors.orange
                        : Colors.green,
                  ),
                  icon: Icon(
                    data['is_verified'] == true ? Icons.cancel : Icons.check,
                  ),
                  label: Text(
                    data['is_verified'] == true ? 'Unverify' : 'Verify',
                  ),
                  onPressed: () async {
                    final newStatus = !(data['is_verified'] == true);

                    // Check if all required fields are filled before verification
                    if (newStatus) {
                      final missingFields = <String>[];
                      if (data['monthly_fee'] == null ||
                          data['monthly_fee'] == 0) {
                        missingFields.add('Monthly Fee');
                      }
                      if (data['service_area'] == null) {
                        missingFields.add('Service Area');
                      }
                      // Check for multiple schools
                      final schoolIds = data['assigned_school_ids'];
                      if (schoolIds == null ||
                          (schoolIds is List && schoolIds.isEmpty)) {
                        missingFields.add('Assigned School(s)');
                      }
                      if (data['assigned_bus_id'] == null ||
                          (data['assigned_bus_id'] as String).isEmpty) {
                        missingFields.add('Assigned Bus');
                      }

                      if (missingFields.isNotEmpty) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot verify driver. Please fill in: ${missingFields.join(', ')}',
                              ),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                        return;
                      }
                    }

                    await service.updateDriver(driverId, {
                      'is_verified': newStatus,
                      'is_searchable': newStatus,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newStatus
                                ? 'Driver verified successfully'
                                : 'Driver verification removed',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Removed delete driver button
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
}

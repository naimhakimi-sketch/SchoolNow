import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_driver_service.dart';
import 'driver_form_screen.dart';
import 'driver_details_page.dart';

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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            DriverDetailsPage(driverId: doc.id),
                      ),
                    );
                  },
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_driver_service.dart';

class ManageDriversScreen extends StatelessWidget {
  const ManageDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminDriverService();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Drivers')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getDrivers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(d['name'] ?? 'Unnamed'),
                subtitle: Text(d['email'] ?? ''),
                trailing: Switch(
                  value: d['is_verified'] == true,
                  onChanged: (v) => service.updateDriver(doc.id, {
                    'is_verified': v,
                    'is_searchable': v,
                  }),
                ),
                onTap: () => _openDriverPanel(context, doc.id, d),
              );
            },
          );
        },
      ),
    );
  }

  void _openDriverPanel(BuildContext context, String id, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
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

    final busCtrl = TextEditingController(text: data['transport_number']);
    final schoolCtrl = TextEditingController(text: data['service_area']?['school_name']);
    final radiusCtrl =
        TextEditingController(text: data['service_area']?['radius_km']?.toString());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Driver Settings', style: Theme.of(context).textTheme.titleLarge),
        TextField(
          controller: busCtrl,
          decoration: const InputDecoration(labelText: 'Bus Plate Number'),
        ),
        TextField(
          controller: schoolCtrl,
          decoration: const InputDecoration(labelText: 'School Name'),
        ),
        TextField(
          controller: radiusCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Radius (km)'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: () async {
            await service.updateDriver(driverId, {
              'transport_number': busCtrl.text.trim(),
              'service_area': {
                'school_name': schoolCtrl.text.trim(),
                'radius_km': int.tryParse(radiusCtrl.text) ?? 0,
              }
            });
            Navigator.pop(context);
          },
        )
      ]),
    );
  }
}

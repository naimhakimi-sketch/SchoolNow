import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/bus_from_driver_service.dart';

class ManageBusesScreen extends StatelessWidget {
  const ManageBusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BusFromDriverService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Buses')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getBuses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No drivers registered yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data() as Map<String, dynamic>;

              final plate = (d['transport_number'] ?? 'Unknown').toString();
              final capacity = (d['seat_capacity'] ?? 0) as int;

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
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    child: const Icon(Icons.directions_bus, color: Colors.indigo),
                  ),
                  title: Text(
                    plate,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Capacity: $capacity seats'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.indigo),
                    onPressed: () => _editCapacity(context, doc.id, capacity),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editCapacity(BuildContext context, String driverId, int currentCapacity) {
    final ctrl = TextEditingController(text: currentCapacity.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Bus Capacity'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Seating Capacity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final value = int.tryParse(ctrl.text) ?? 0;
              if (value <= 0) return;

              await BusFromDriverService().updateBusCapacity(driverId, value);

              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

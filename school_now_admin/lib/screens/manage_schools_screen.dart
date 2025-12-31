import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/school_service.dart';
import 'map_picker_screen.dart';

class ManageSchoolsScreen extends StatelessWidget {
  const ManageSchoolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SchoolService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Manage Schools')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add School'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getSchools(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No schools added yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

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
                    backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                    child: const Icon(Icons.school, color: Colors.indigo),
                  ),
                  title: Text(
                    data['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${data['type']} • ${data['address']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.indigo),
                        onPressed: () =>
                            _openForm(context, id: doc.id, existing: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => service.deleteSchool(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openForm(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?['name']);
    final addressCtrl = TextEditingController(text: existing?['address']);
    String type = existing?['type'] ?? 'Primary';

    HomeAddressPickerResult? pickedResult;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(id == null ? 'Add School' : 'Edit School'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'Primary', child: Text('Primary')),
                  DropdownMenuItem(
                    value: 'Secondary',
                    child: Text('Secondary'),
                  ),
                ],
                onChanged: (v) => type = v!,
                decoration: const InputDecoration(
                  labelText: 'School Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 🗺️ Map Picker Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Pick Location on Map'),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeAddressPickerPage(),
                      ),
                    );

                    if (result != null) {
                      pickedResult = result;
                      addressCtrl.text = result.displayName;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final service = SchoolService();

              final location = GeoPoint(
                pickedResult?.lat ?? 0,
                pickedResult?.lng ?? 0,
              );

              if (id == null) {
                await service.addSchool(
                  name: nameCtrl.text,
                  type: type,
                  address: addressCtrl.text,
                  location: location,
                );
              } else {
                await service.updateSchool(
                  id,
                  name: nameCtrl.text,
                  type: type,
                  address: addressCtrl.text,
                  location: location,
                );
              }

              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

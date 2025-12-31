import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/parent_service.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final _parentService = ParentService();

  final _childNameController = TextEditingController();
  final _childIcController = TextEditingController();

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  List<QueryDocumentSnapshot> _schools = [];
  bool _loadingSchools = true;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _schools = snapshot.docs;
          _loadingSchools = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSchools = false;
          _error = 'Failed to load schools: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _childIcController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final childName = _childNameController.text.trim();
      final childIc = _childIcController.text.trim();

      if (childName.isEmpty) throw Exception('Child name is required');
      if (childIc.isEmpty) throw Exception('Child IC is required');
      if (_selectedSchoolId == null) throw Exception('Please select a school');

      await _parentService.addChild(
        parentId: uid,
        childName: childName,
        childIcNumber: childIc,
        schoolName: _selectedSchoolName!,
        schoolId: _selectedSchoolId!,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to add child: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Child')),
      body: _loadingSchools
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _childNameController,
                  decoration: const InputDecoration(labelText: 'Child Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _childIcController,
                  decoration: const InputDecoration(labelText: 'Child IC'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSchoolId,
                    decoration: const InputDecoration(
                      labelText: 'Select School',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    hint: const Text('Choose a school'),
                    items: _schools.map((school) {
                      final data = school.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: school.id,
                        child: Text(
                          '${data['name'] ?? 'Unknown'} (${data['type'] ?? ''})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final school = _schools.firstWhere(
                          (s) => s.id == value,
                        );
                        final data = school.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedSchoolId = value;
                          _selectedSchoolName = data['name'] ?? 'Unknown';
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a school';
                      }
                      return null;
                    },
                  ),
                ),
                if (_selectedSchoolId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: $_selectedSchoolName',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Save Child'),
                  ),
                ),
              ],
            ),
    );
  }
}

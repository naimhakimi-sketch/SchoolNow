import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/parent_service.dart';

class EditChildPage extends StatefulWidget {
  final String parentId;
  final String childId;
  final String initialChildName;
  final String initialChildIc;
  final String initialSchoolName;
  final String? initialSchoolId;

  const EditChildPage({
    super.key,
    required this.parentId,
    required this.childId,
    required this.initialChildName,
    required this.initialChildIc,
    required this.initialSchoolName,
    this.initialSchoolId,
  });

  @override
  State<EditChildPage> createState() => _EditChildPageState();
}

class _EditChildPageState extends State<EditChildPage> {
  final _parentService = ParentService();

  late final TextEditingController _childNameController;
  late final TextEditingController _childIcController;

  String? _selectedSchoolId;
  String? _selectedSchoolName;

  List<QueryDocumentSnapshot> _schools = [];
  bool _loadingSchools = true;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _childNameController = TextEditingController(text: widget.initialChildName);
    _childIcController = TextEditingController(text: widget.initialChildIc);
    _selectedSchoolId = widget.initialSchoolId;
    _selectedSchoolName = widget.initialSchoolName;
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    int attempts = 0;
    const maxAttempts = 5;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        // Use timeout to prevent indefinite hangs
        final snapshot = await FirebaseFirestore.instance
            .collection('schools')
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Schools fetch timeout'),
            );

        final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
        docs.sort((a, b) {
          final an = (a.data() as Map<String, dynamic>)['name'] ?? '';
          final bn = (b.data() as Map<String, dynamic>)['name'] ?? '';
          return an.toString().toLowerCase().compareTo(
            bn.toString().toLowerCase(),
          );
        });

        if (mounted) {
          setState(() {
            _schools = docs;
            _loadingSchools = false;
          });
        }
        return;
      } catch (e) {
        final text = e.toString();
        final isFirestoreAssertion =
            text.contains('INTERNAL ASSERTION FAILED') ||
            text.contains('Unexpected state') ||
            text.contains('assertion failed');
        final isTimeout = e is TimeoutException;

        if ((isFirestoreAssertion || isTimeout) && attempts < maxAttempts) {
          // Exponential backoff: 800ms, 1600ms, 3200ms, 6400ms
          final delayMs = 800 * (1 << (attempts - 1));
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        if (mounted) {
          setState(() {
            _loadingSchools = false;
            _error = 'Failed to load schools. Please try again.';
          });
        }
        return;
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

    if (uid != widget.parentId) {
      setState(() {
        _error = 'Unauthorized parent account.';
      });
      return;
    }

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

      await _parentService.updateChild(
        parentId: widget.parentId,
        childId: widget.childId,
        childName: childName,
        childIcNumber: childIc,
        schoolName: _selectedSchoolName!,
        schoolId: _selectedSchoolId!,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to update child: $e';
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
      appBar: AppBar(title: const Text('Edit Child')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _childNameController,
            decoration: const InputDecoration(labelText: 'Child Name'),
          ),
          TextField(
            controller: _childIcController,
            decoration: const InputDecoration(labelText: 'Child IC'),
          ),
          if (_loadingSchools)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSchoolId,
                decoration: const InputDecoration(labelText: 'School'),
                items: _schools.map((school) {
                  final schoolData = school.data() as Map<String, dynamic>;
                  final schoolName = schoolData['name'] ?? 'Unknown';
                  return DropdownMenuItem<String>(
                    value: school.id,
                    child: Text(schoolName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final school = _schools.firstWhere((s) => s.id == value);
                    final schoolData = school.data() as Map<String, dynamic>?;
                    setState(() {
                      _selectedSchoolId = value;
                      _selectedSchoolName = schoolData?['name'] ?? 'Unknown';
                    });
                  }
                },
              ),
            ),
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
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

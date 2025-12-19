import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/parent_service.dart';
import '../location/school_map_picker_page.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final _parentService = ParentService();

  final _childNameController = TextEditingController();
  final _childIcController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _schoolLatController = TextEditingController();
  final _schoolLngController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _pickSchoolOnMap() async {
    final initialLat = double.tryParse(_schoolLatController.text.trim());
    final initialLng = double.tryParse(_schoolLngController.text.trim());

    final result = await Navigator.of(context).push<SchoolMapPickerResult>(
      MaterialPageRoute(
        builder: (_) => SchoolMapPickerPage(
          initialLat: initialLat,
          initialLng: initialLng,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _schoolLatController.text = result.lat.toStringAsFixed(6);
      _schoolLngController.text = result.lng.toStringAsFixed(6);
      final display = (result.displayName ?? '').trim();
      if (display.isNotEmpty) {
        _schoolNameController.text = display;
      }
    });
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _childIcController.dispose();
    _schoolNameController.dispose();
    _schoolLatController.dispose();
    _schoolLngController.dispose();
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
      final schoolName = _schoolNameController.text.trim();
      final schoolLat = double.tryParse(_schoolLatController.text.trim());
      final schoolLng = double.tryParse(_schoolLngController.text.trim());

      if (childName.isEmpty) throw Exception('Child name is required');
      if (childIc.isEmpty) throw Exception('Child IC is required');
      if (schoolName.isEmpty) throw Exception('School name is required');

      await _parentService.addChild(
        parentId: uid,
        childName: childName,
        childIcNumber: childIc,
        schoolName: schoolName,
        schoolLat: schoolLat,
        schoolLng: schoolLng,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _childNameController, decoration: const InputDecoration(labelText: 'Child Name')),
          TextField(controller: _childIcController, decoration: const InputDecoration(labelText: 'Child IC')),
          TextField(controller: _schoolNameController, decoration: const InputDecoration(labelText: 'School (name)')),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _pickSchoolOnMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Choose & search school on map'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _schoolLatController,
                  decoration: const InputDecoration(labelText: 'School Lat'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _schoolLngController,
                  decoration: const InputDecoration(labelText: 'School Lng'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading ? const CircularProgressIndicator() : const Text('Save Child'),
            ),
          ),
        ],
      ),
    );
  }
}

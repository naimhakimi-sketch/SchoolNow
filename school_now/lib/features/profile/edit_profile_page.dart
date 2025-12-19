import 'package:flutter/material.dart';

import '../../services/parent_service.dart';

class EditProfilePage extends StatefulWidget {
  final String parentId;
  final String name;
  final String contactNumber;
  final String address;
  final bool addressLocked;

  const EditProfilePage({
    super.key,
    required this.parentId,
    required this.name,
    required this.contactNumber,
    required this.address,
    required this.addressLocked,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _service = ParentService();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _addressController;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _contactController = TextEditingController(text: widget.contactNumber);
    _addressController = TextEditingController(text: widget.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final patch = <String, dynamic>{
        'name': _nameController.text.trim(),
        'contact_number': _contactController.text.trim(),
      };
      if (!widget.addressLocked) {
        patch['address'] = _addressController.text.trim();
      }

      await _service.updateParent(widget.parentId, patch);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(labelText: 'Contact'),
            keyboardType: TextInputType.phone,
          ),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address',
              helperText: widget.addressLocked ? 'Locked after driver assignment' : null,
            ),
            enabled: !widget.addressLocked,
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

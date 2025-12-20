import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/parent_service.dart';
import '../location/school_map_picker_page.dart';

class EditChildPage extends StatefulWidget {
  final String parentId;
  final String childId;
  final String initialChildName;
  final String initialChildIc;
  final String initialSchoolName;
  final double? initialSchoolLat;
  final double? initialSchoolLng;
  final double? initialPickupLat;
  final double? initialPickupLng;

  const EditChildPage({
    super.key,
    required this.parentId,
    required this.childId,
    required this.initialChildName,
    required this.initialChildIc,
    required this.initialSchoolName,
    required this.initialSchoolLat,
    required this.initialSchoolLng,
    required this.initialPickupLat,
    required this.initialPickupLng,
  });

  @override
  State<EditChildPage> createState() => _EditChildPageState();
}

class _EditChildPageState extends State<EditChildPage> {
  final _parentService = ParentService();

  late final TextEditingController _childNameController;
  late final TextEditingController _childIcController;
  late final TextEditingController _schoolNameController;
  late final TextEditingController _schoolLatController;
  late final TextEditingController _schoolLngController;
  late final TextEditingController _pickupLatController;
  late final TextEditingController _pickupLngController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _childNameController = TextEditingController(text: widget.initialChildName);
    _childIcController = TextEditingController(text: widget.initialChildIc);
    _schoolNameController = TextEditingController(text: widget.initialSchoolName);
    _schoolLatController = TextEditingController(
      text: widget.initialSchoolLat == null ? '' : widget.initialSchoolLat!.toStringAsFixed(6),
    );
    _schoolLngController = TextEditingController(
      text: widget.initialSchoolLng == null ? '' : widget.initialSchoolLng!.toStringAsFixed(6),
    );
    _pickupLatController = TextEditingController(
      text: widget.initialPickupLat == null ? '' : widget.initialPickupLat!.toStringAsFixed(6),
    );
    _pickupLngController = TextEditingController(
      text: widget.initialPickupLng == null ? '' : widget.initialPickupLng!.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _childIcController.dispose();
    _schoolNameController.dispose();
    _schoolLatController.dispose();
    _schoolLngController.dispose();
    _pickupLatController.dispose();
    _pickupLngController.dispose();
    super.dispose();
  }

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

  Future<void> _pickPickupOnMap() async {
    final initialLat = double.tryParse(_pickupLatController.text.trim());
    final initialLng = double.tryParse(_pickupLngController.text.trim());

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
      _pickupLatController.text = result.lat.toStringAsFixed(6);
      _pickupLngController.text = result.lng.toStringAsFixed(6);
    });
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
      final schoolName = _schoolNameController.text.trim();
      final schoolLat = double.tryParse(_schoolLatController.text.trim());
      final schoolLng = double.tryParse(_schoolLngController.text.trim());
      final pickupLat = double.tryParse(_pickupLatController.text.trim());
      final pickupLng = double.tryParse(_pickupLngController.text.trim());

      if (childName.isEmpty) throw Exception('Child name is required');
      if (childIc.isEmpty) throw Exception('Child IC is required');
      if (schoolName.isEmpty) throw Exception('School name is required');

      await _parentService.updateChild(
        parentId: widget.parentId,
        childId: widget.childId,
        childName: childName,
        childIcNumber: childIc,
        schoolName: schoolName,
        schoolLat: schoolLat,
        schoolLng: schoolLng,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
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
          Text('Pickup location', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _pickPickupOnMap,
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Choose pickup location on map'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pickupLatController,
                  decoration: const InputDecoration(labelText: 'Pickup Lat'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pickupLngController,
                  decoration: const InputDecoration(labelText: 'Pickup Lng'),
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
              child: _loading ? const CircularProgressIndicator() : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

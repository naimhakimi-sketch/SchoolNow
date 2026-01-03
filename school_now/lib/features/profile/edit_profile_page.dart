import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/parent_service.dart';
import '../location/location_picker_page.dart';

class EditProfilePage extends StatefulWidget {
  final String parentId;
  final String name;
  final String contactNumber;
  final String address;
  final bool pickupLocationLocked;

  const EditProfilePage({
    super.key,
    required this.parentId,
    required this.name,
    required this.contactNumber,
    required this.address,
    required this.pickupLocationLocked,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _service = ParentService();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _addressController;

  LatLng? _selectedLocation;
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
    if (widget.pickupLocationLocked) {
      setState(() {
        _error = 'Pickup location is locked during active trip';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final patch = <String, dynamic>{
        'name': _nameController.text.trim(),
        'contact_number': _contactController.text.trim(),
      };

      if (_selectedLocation != null) {
        // Save both the address and the pickup_location with lat/lng
        patch['address'] = _addressController.text.trim();
        patch['pickup_location'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
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
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(labelText: 'Contact'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          Text('Pickup Location', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address',
              helperText: widget.pickupLocationLocked
                  ? 'Locked during active trip'
                  : 'Selected from map',
              suffixIcon: const Icon(Icons.location_on),
            ),
            enabled: false,
            readOnly: true,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.pickupLocationLocked
                ? null
                : () async {
                    final result = await Navigator.of(context)
                        .push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => LocationPickerPage(
                              initialLocation: _selectedLocation,
                            ),
                          ),
                        );

                    if (result != null && mounted) {
                      setState(() {
                        _selectedLocation = LatLng(
                          result['lat'] as double,
                          result['lng'] as double,
                        );
                        _addressController.text =
                            result['address'] as String? ?? '';
                      });
                    }
                  },
            icon: const Icon(Icons.map),
            label: const Text('Pick Location on Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.pickupLocationLocked ? Colors.grey : null,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || widget.pickupLocationLocked ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

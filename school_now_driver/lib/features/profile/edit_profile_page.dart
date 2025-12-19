import 'package:flutter/material.dart';

import '../../services/driver_service.dart';

class EditProfilePage extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic>? initialData;

  const EditProfilePage({
    super.key,
    required this.driverId,
    required this.initialData,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _transportController = TextEditingController();
  final _seatCapacityController = TextEditingController();
  final _monthlyFeeController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? const <String, dynamic>{};
    _nameController.text = (d['name'] ?? '').toString();
    _contactController.text = (d['contact_number'] ?? '').toString();
    _addressController.text = (d['address'] ?? '').toString();
    _transportController.text = (d['transport_number'] ?? '').toString();
    _seatCapacityController.text = (d['seat_capacity'] ?? '').toString();
    _monthlyFeeController.text = (d['monthly_fee'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _transportController.dispose();
    _seatCapacityController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final contact = _contactController.text.trim();
      final address = _addressController.text.trim();
      final transport = _transportController.text.trim();

      final seatCapacity = int.tryParse(_seatCapacityController.text.trim());
      if (seatCapacity == null || seatCapacity <= 0) {
        throw Exception('Seat capacity must be a positive number.');
      }

      final monthlyFeeRaw = _monthlyFeeController.text.trim();
      final monthlyFee = double.tryParse(monthlyFeeRaw);
      if (monthlyFee == null || monthlyFee < 0) {
        throw Exception('Monthly fee must be a valid number.');
      }

      if (name.isEmpty) {
        throw Exception('Name is required.');
      }

      await DriverService().updateDriver(
        widget.driverId,
        {
          'name': name,
          'contact_number': contact,
          'address': address,
          'transport_number': transport,
          'seat_capacity': seatCapacity,
          'monthly_fee': monthlyFee,
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
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
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Contact Number'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Home/Operator Address'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _transportController,
              decoration: const InputDecoration(labelText: 'Registered Transport Number'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _seatCapacityController,
              decoration: const InputDecoration(labelText: 'Vehicle Seat Capacity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _monthlyFeeController,
              decoration: const InputDecoration(labelText: 'Monthly Fee'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

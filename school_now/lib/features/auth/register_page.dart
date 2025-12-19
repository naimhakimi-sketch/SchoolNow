import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../children/add_child_page.dart';
import '../location/home_address_picker_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = ParentAuthService();

  final _icController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  double? _pickupLat;
  double? _pickupLng;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _icController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_passwordController.text != _confirmController.text) {
        throw Exception('Passwords do not match');
      }

      await _auth.registerParent(
        icNumber: _icController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        contactNumber: _contactController.text.trim(),
        address: _addressController.text.trim(),
        password: _passwordController.text,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
      );

      if (!mounted) return;
      // Immediately prompt to add a child (SRS FR-PA-1.2).
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AddChildPage()));
    } catch (e) {
      setState(() {
        _error = 'Registration failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickPickupPoint() async {
    if (_loading) return;

    final result = await Navigator.of(context).push<HomeAddressPickerResult>(
      MaterialPageRoute(
        builder: (_) => HomeAddressPickerPage(
          initialQuery: _addressController.text.trim(),
          initialLat: _pickupLat,
          initialLng: _pickupLng,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _pickupLat = result.lat;
      _pickupLng = result.lng;
      if (result.displayName.trim().isNotEmpty) {
        _addressController.text = result.displayName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Registration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _icController, decoration: const InputDecoration(labelText: 'IC Number')),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(labelText: 'Contact'),
            keyboardType: TextInputType.phone,
          ),
          TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Home Address (Pickup Point)')),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : _pickPickupPoint,
              icon: const Icon(Icons.home),
              label: Text(
                _pickupLat != null && _pickupLng != null ? 'Pickup point selected' : 'Pick pickup point on map',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          TextField(controller: _confirmController, decoration: const InputDecoration(labelText: 'Confirm Password'), obscureText: true),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading ? const CircularProgressIndicator() : const Text('Register'),
            ),
          ),
        ],
      ),
    );
  }
}

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AddChildPage()),
      );
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
      appBar: AppBar(
        title: Image.asset('launcher/title.png', height: 40),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const SizedBox(height: 16),
          Text(
            'Register as Parent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in your details to create an account',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _icController,
            decoration: InputDecoration(
              labelText: 'IC Number',
              prefixIcon: const Icon(Icons.person_outline),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactController,
            decoration: InputDecoration(
              labelText: 'Contact Number',
              prefixIcon: const Icon(Icons.phone_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Home Address (Pickup Point)',
              prefixIcon: const Icon(Icons.home_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loading ? null : _pickPickupPoint,
            icon: const Icon(Icons.location_on),
            label: Text(
              _pickupLat != null && _pickupLng != null
                  ? '✓ Location selected on map'
                  : 'Pick location on map',
              style: const TextStyle(fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFECCC6E),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black87),
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

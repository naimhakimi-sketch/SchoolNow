import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'home_address_picker_page.dart';
import 'school_map_picker_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = AuthService();
  final _icController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  double? _homeLat;
  double? _homeLng;
  final _transportNumberController = TextEditingController();
  final _seatCapacityController = TextEditingController();
  final _monthlyFeeController = TextEditingController();

  final _schoolNameController = TextEditingController();
  final _schoolLatController = TextEditingController();
  final _schoolLngController = TextEditingController();

  String _serviceSide = 'north';
  final _radiusKmController = TextEditingController(text: '10');

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
    _transportNumberController.dispose();
    _seatCapacityController.dispose();
    _monthlyFeeController.dispose();
    _schoolNameController.dispose();
    _schoolLatController.dispose();
    _schoolLngController.dispose();
    _radiusKmController.dispose();
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
      final icNumber = _icController.text.trim();
      final fullName = _nameController.text.trim();
      final email = _emailController.text.trim();
      final contactNumber = _contactController.text.trim();
      final address = _addressController.text.trim();
      final transportNumber = _transportNumberController.text.trim();

      final seatCapacity = int.tryParse(_seatCapacityController.text.trim());
      final monthlyFee = double.tryParse(_monthlyFeeController.text.trim());
      final radiusKm = double.tryParse(_radiusKmController.text.trim());
      final schoolName = _schoolNameController.text.trim();
      final schoolLat = double.tryParse(_schoolLatController.text.trim());
      final schoolLng = double.tryParse(_schoolLngController.text.trim());

      if (icNumber.isEmpty) throw Exception('IC number is required');
      if (fullName.isEmpty) throw Exception('Full name is required');
      if (email.isEmpty) throw Exception('Email is required');
      if (contactNumber.isEmpty) throw Exception('Contact number is required');
      if (address.isEmpty) throw Exception('Home/Operator address is required');
      if (transportNumber.isEmpty) {
        throw Exception('Registered school transportation number is required');
      }
      if (seatCapacity == null || seatCapacity <= 0) {
        throw Exception('Vehicle seat capacity must be a positive number');
      }
      if (monthlyFee == null || monthlyFee < 0) {
        throw Exception('Monthly fee must be a valid number');
      }

      if (schoolName.isEmpty) throw Exception('School name is required');
      if (schoolLat == null || schoolLng == null) {
        throw Exception('School latitude/longitude are required');
      }
      if (radiusKm == null || radiusKm <= 0) {
        throw Exception('Service radius must be a positive number (km)');
      }

      if (_passwordController.text != _confirmController.text) {
        throw Exception('Passwords do not match');
      }
      await _auth.registerWithEmail(
        icNumber: icNumber,
        name: fullName,
        email: email,
        contactNumber: contactNumber,
        address: address,
        homeLat: _homeLat,
        homeLng: _homeLng,
        transportNumber: transportNumber,
        seatCapacity: seatCapacity,
        monthlyFee: monthlyFee,
        serviceAreaSchoolName: schoolName,
        serviceAreaSchoolLat: schoolLat,
        serviceAreaSchoolLng: schoolLng,
        serviceAreaSide: _serviceSide,
        serviceAreaRadiusKm: radiusKm,
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickSchoolLocation() async {
    if (_loading) return;

    final initialLat = double.tryParse(_schoolLatController.text.trim());
    final initialLng = double.tryParse(_schoolLngController.text.trim());

    final result = await Navigator.of(context).push<SchoolMapPickerResult>(
      MaterialPageRoute(
        builder: (_) =>
            SchoolMapPickerPage(initialLat: initialLat, initialLng: initialLng),
      ),
    );

    if (result == null) return;

    setState(() {
      _schoolLatController.text = result.lat.toStringAsFixed(6);
      _schoolLngController.text = result.lng.toStringAsFixed(6);
    });
  }

  Future<void> _pickHomeLocation() async {
    if (_loading) return;

    final result = await Navigator.of(context).push<HomeAddressPickerResult>(
      MaterialPageRoute(
        builder: (_) => HomeAddressPickerPage(
          initialQuery: _addressController.text.trim(),
          initialLat: _homeLat,
          initialLng: _homeLng,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _homeLat = result.lat;
      _homeLng = result.lng;
      if (result.displayName.trim().isNotEmpty) {
        _addressController.text = result.displayName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _icController,
                decoration: const InputDecoration(labelText: 'IC Number'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Home/Operator Address (Starting Point)',
                ),
                textInputAction: TextInputAction.next,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _pickHomeLocation,
                  icon: const Icon(Icons.home),
                  label: Text(
                    _homeLat != null && _homeLng != null
                        ? 'Home location selected'
                        : 'Pick home on map (search address)',
                  ),
                ),
              ),
              TextField(
                controller: _transportNumberController,
                decoration: const InputDecoration(
                  labelText: 'Registered School Transportation Number',
                ),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _seatCapacityController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Seat Capacity',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _monthlyFeeController,
                decoration: const InputDecoration(labelText: 'Monthly Fee'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Service Area',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _schoolNameController,
                decoration: const InputDecoration(labelText: 'School Name'),
                textInputAction: TextInputAction.next,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _schoolLatController,
                      decoration: const InputDecoration(
                        labelText: 'School Lat',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _schoolLngController,
                      decoration: const InputDecoration(
                        labelText: 'School Lng',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _pickSchoolLocation,
                  icon: const Icon(Icons.map),
                  label: const Text('Pick school on map'),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _serviceSide,
                decoration: const InputDecoration(
                  labelText: 'Side (North/South/East/West)',
                ),
                items: const [
                  DropdownMenuItem(value: 'north', child: Text('North')),
                  DropdownMenuItem(value: 'south', child: Text('South')),
                  DropdownMenuItem(value: 'east', child: Text('East')),
                  DropdownMenuItem(value: 'west', child: Text('West')),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _serviceSide = v;
                        });
                      },
              ),
              TextField(
                controller: _radiusKmController,
                decoration: const InputDecoration(labelText: 'Radius (km)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                obscureText: true,
              ),

              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Note: Profile becomes searchable to parents after you enable visibility.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

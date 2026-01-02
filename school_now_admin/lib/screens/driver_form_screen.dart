import 'dart:math' show cos, asin, sqrt, sin;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_driver_service.dart';
import '../services/bus_from_driver_service.dart';
import 'service_area_picker_screen.dart';

class DriverFormScreen extends StatefulWidget {
  final String? driverId;
  final Map<String, dynamic>? initialData;

  const DriverFormScreen({super.key, this.driverId, this.initialData});

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _icController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _licenseController = TextEditingController();
  final _monthlyFeeController = TextEditingController();

  String? _selectedBusId;
  List<String> _selectedSchoolIds = [];
  Map<String, dynamic>? _serviceArea;
  bool _loading = false;

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Don't populate initial data here - do it after _loadData completes
  }

  void _populateInitialDataFromData(Map<String, dynamic> data) {
    _icController.text = data['ic_number'] ?? '';
    _nameController.text = data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _contactController.text = data['contact_number'] ?? '';
    _licenseController.text = data['license_number'] ?? '';
    _monthlyFeeController.text = data['monthly_fee']?.toString() ?? '';
    _selectedBusId = data['assigned_bus_id'];

    // Handle multiple schools
    if (data['assigned_school_ids'] != null) {
      _selectedSchoolIds = List<String>.from(data['assigned_school_ids']);
    } else if (data['assigned_school_id'] != null) {
      // Backward compatibility for old single school format
      _selectedSchoolIds = [data['assigned_school_id']];
    }

    _serviceArea = data['service_area'];
  }

  Future<void> _loadData() async {
    final service = AdminDriverService();
    final busService = BusService();

    // If editing an existing driver, always fetch fresh data from Firebase
    Map<String, dynamic>? driverData = widget.initialData;
    if (widget.driverId != null) {
      try {
        final driverDoc = await service.getDriverById(widget.driverId!);
        driverData = driverDoc.data() as Map<String, dynamic>?;
      } catch (e) {
        // If fetching fails, fall back to initialData
        driverData = widget.initialData;
      }
    }

    final allBuses = await busService.getAvailableBuses();
    final schools = await service.getAvailableSchools();

    // Filter buses: only show unassigned buses or the current driver's bus
    final availableBuses = allBuses.where((bus) {
      final assignedDriverId = bus['assigned_driver_id'];
      // Include: unassigned buses, or buses assigned to this driver
      return assignedDriverId == null ||
          assignedDriverId.isEmpty ||
          assignedDriverId == widget.driverId;
    }).toList();

    // Always include the currently selected bus if it's assigned to someone else
    if (_selectedBusId != null && _selectedBusId != 'none') {
      final currentBus = allBuses.firstWhere(
        (bus) => bus['id'] == _selectedBusId,
        orElse: () => <String, dynamic>{},
      );
      if (currentBus.isNotEmpty && !availableBuses.contains(currentBus)) {
        availableBuses.add(currentBus);
      }
    }

    // Remove duplicate buses (by plate_number)
    final seenPlates = <String>{};
    final uniqueBuses = <Map<String, dynamic>>[];
    for (final bus in availableBuses) {
      final plateNumber = bus['plate_number'] as String?;
      if (plateNumber != null && !seenPlates.contains(plateNumber)) {
        seenPlates.add(plateNumber);
        uniqueBuses.add(bus);
      }
    }

    setState(() {
      _buses = uniqueBuses;
      _schools = schools;
    });

    // Now populate initial data after buses and schools are loaded
    if (driverData != null) {
      _populateInitialDataFromData(driverData);
      setState(() {
        // Trigger rebuild with populated initial data
      });
    }
  }

  Future<void> _pickServiceArea() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceAreaPickerScreen(
          initialSchoolId: _selectedSchoolIds.isNotEmpty
              ? _selectedSchoolIds.first
              : null,
          initialServiceArea: _serviceArea,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _serviceArea = result;
        // Remove schools that are outside the new service area
        _selectedSchoolIds.removeWhere((schoolId) {
          return !_isSchoolInServiceArea(schoolId);
        });
      });
    }
  }

  bool _isSchoolInServiceArea(String schoolId) {
    if (_serviceArea == null) return true;

    final school = _schools.firstWhere(
      (s) => s['id'] == schoolId,
      orElse: () => {},
    );

    if (school.isEmpty) {
      return false;
    }

    // If school doesn't have geo_location, allow it (service area is optional)
    if (school['geo_location'] == null) {
      return true;
    }

    final schoolLat = school['geo_location']['lat'] as double?;
    final schoolLng = school['geo_location']['lng'] as double?;
    final centerLat = _serviceArea!['center_lat'] as double?;
    final centerLng = _serviceArea!['center_lng'] as double?;
    final radiusKm = _serviceArea!['radius_km'] as double?;

    if (schoolLat == null ||
        schoolLng == null ||
        centerLat == null ||
        centerLng == null ||
        radiusKm == null) {
      return false;
    }

    // Calculate distance using Haversine formula
    const earthRadius = 6371.0; // km
    final dLat = (schoolLat - centerLat) * (3.14159265359 / 180);
    final dLng = (schoolLng - centerLng) * (3.14159265359 / 180);

    final lat1Rad = centerLat * (3.14159265359 / 180);
    final lat2Rad = schoolLat * (3.14159265359 / 180);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(a));
    final distance = earthRadius * c;

    return distance <= radiusKm;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final service = AdminDriverService();

      final data = {
        'ic_number': _icController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'contact_number': _contactController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'monthly_fee': _monthlyFeeController.text.trim().isEmpty
            ? 0
            : double.tryParse(_monthlyFeeController.text.trim()) ?? 0,
        'assigned_school_ids': _selectedSchoolIds,
        if (_serviceArea != null) 'service_area': _serviceArea,
      };
      // Only add assigned_bus_id if not null, otherwise delete the field
      final updatePatch = Map<String, dynamic>.from(data);
      if (_selectedBusId != null) {
        updatePatch['assigned_bus_id'] = _selectedBusId;
      } else {
        updatePatch['assigned_bus_id'] = FieldValue.delete();
      }

      if (widget.driverId == null) {
        await service.addDriver(
          icNumber: data['ic_number'] as String,
          name: data['name'] as String,
          email: data['email'] as String,
          contactNumber: data['contact_number'] as String,
          licenseNumber: data['license_number'] as String,
          monthlyFee: data['monthly_fee'] as double,
          assignedBusId: _selectedBusId, // always String? or null
          assignedSchoolIds: _selectedSchoolIds,
          serviceArea: _serviceArea,
        );
      } else {
        await service.updateDriver(widget.driverId!, updatePatch);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.driverId == null
                  ? 'Driver added successfully'
                  : 'Driver updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _icController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _licenseController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driverId == null ? 'Add Driver' : 'Edit Driver'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact Number *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseController,
              decoration: const InputDecoration(
                labelText: 'License Number',
                border: OutlineInputBorder(),
                hintText: 'Driver\'s license number',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _monthlyFeeController,
              decoration: const InputDecoration(
                labelText: 'Monthly Fee (RM)',
                border: OutlineInputBorder(),
                hintText: 'Monthly service fee',
                prefixText: 'RM ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Assignments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedBusId ?? 'none',
              decoration: const InputDecoration(
                labelText: 'Assign Bus (Optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'none', child: Text('No Bus')),
                ..._buses.map((bus) {
                  return DropdownMenuItem(
                    value: bus['id'],
                    child: Text(
                      '${bus['plate_number']} (${bus['capacity']} seats)',
                    ),
                  );
                }),
              ],
              onChanged: (v) =>
                  setState(() => _selectedBusId = v == 'none' ? null : v),
            ),
            const SizedBox(height: 16),

            // Multiple School Selection
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign Schools',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._selectedSchoolIds.map((schoolId) {
                        final school = _schools.firstWhere(
                          (s) => s['id'] == schoolId,
                          orElse: () => {'name': 'Unknown', 'type': ''},
                        );
                        return Chip(
                          label: Text('${school['name']} (${school['type']})'),
                          onDeleted: () {
                            setState(() {
                              _selectedSchoolIds.remove(schoolId);
                            });
                          },
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add School'),
                        onPressed: () async {
                          // Check if service area is set
                          if (_serviceArea == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please set service area first before adding schools',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Filter schools within service area
                          final availableSchools = _schools
                              .where(
                                (s) =>
                                    !_selectedSchoolIds.contains(s['id']) &&
                                    _isSchoolInServiceArea(s['id']),
                              )
                              .toList();

                          if (availableSchools.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No schools available within the service area',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            return;
                          }

                          final selectedSchool = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select School'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: availableSchools
                                      .map(
                                        (school) => ListTile(
                                          title: Text(school['name']),
                                          subtitle: Text(school['type']),
                                          onTap: () => Navigator.pop(
                                            context,
                                            school['id'],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                          if (selectedSchool != null) {
                            setState(() {
                              _selectedSchoolIds.add(selectedSchool);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickServiceArea,
              icon: const Icon(Icons.map),
              label: Text(
                _serviceArea == null
                    ? 'Set Service Area'
                    : 'Service Area: ${_serviceArea!['radius_km']} km radius',
              ),
            ),
            if (_serviceArea != null) ...[
              const SizedBox(height: 8),
              Text(
                'Center: (${_serviceArea!['center_lat'].toStringAsFixed(6)}, ${_serviceArea!['center_lng'].toStringAsFixed(6)})',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Save Driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show cos, asin, sqrt, sin;
import '../services/admin_driver_service.dart';
import '../services/bus_from_driver_service.dart';
import 'service_area_picker_screen.dart';

class DriverDetailsPage extends StatefulWidget {
  final String driverId;

  const DriverDetailsPage({super.key, required this.driverId});

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AdminDriverService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _service.getDriverById(widget.driverId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Driver Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final driver = snapshot.data!.data() as Map<String, dynamic>;
        final name = driver['name'] ?? 'Unnamed Driver';

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Details', icon: Icon(Icons.person)),
                Tab(text: 'Trips', icon: Icon(Icons.history)),
                Tab(text: 'Students', icon: Icon(Icons.people)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _DriverDetailsTab(driverId: widget.driverId, driver: driver),
              _TripsHistoryTab(driverId: widget.driverId),
              _StudentsListTab(driverId: widget.driverId),
            ],
          ),
        );
      },
    );
  }
}

class _DriverDetailsTab extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driver;

  const _DriverDetailsTab({required this.driverId, required this.driver});

  @override
  State<_DriverDetailsTab> createState() => _DriverDetailsTabState();
}

class _DriverDetailsTabState extends State<_DriverDetailsTab> {
  late Map<String, dynamic> _editingDriver;
  bool _isEditing = false;
  final _service = AdminDriverService();
  final _busService = BusService();

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _schools = [];
  String? _selectedBusId;
  List<String> _selectedSchoolIds = [];
  Map<String, dynamic>? _serviceArea;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    _editingDriver = Map.from(widget.driver);
    _selectedBusId = widget.driver['assigned_bus_id'];
    _selectedSchoolIds = List<String>.from(
      widget.driver['assigned_school_ids'] ?? [],
    );
    _serviceArea = widget.driver['service_area'];
    _loadBusesAndSchools();
  }

  Future<void> _loadBusesAndSchools() async {
    setState(() => _loadingData = true);
    try {
      final allBuses = await _busService.getAvailableBuses();
      final schools = await _service.getAvailableSchools();

      // Filter buses: only show unassigned buses or the current driver's bus
      final availableBuses = allBuses.where((bus) {
        final assignedDriverId = bus['assigned_driver_id'];
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
        _loadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading buses and schools: $e');
      setState(() => _loadingData = false);
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

    const earthRadius = 6371.0;
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
        _editingDriver['service_area'] = result;
        // Remove schools that are outside the new service area
        _selectedSchoolIds.removeWhere((schoolId) {
          return !_isSchoolInServiceArea(schoolId);
        });
        _editingDriver['assigned_school_ids'] = _selectedSchoolIds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Driver Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!_isEditing)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                )
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _editingDriver = Map.from(widget.driver);
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailField(
            label: 'Name',
            value: _editingDriver['name'] ?? '',
            editable: _isEditing,
            onChanged: (v) => _editingDriver['name'] = v,
          ),
          const SizedBox(height: 16),
          _buildDetailField(
            label: 'Email',
            value: _editingDriver['email'] ?? '',
            editable: _isEditing,
            onChanged: (v) => _editingDriver['email'] = v,
          ),
          const SizedBox(height: 16),
          _buildDetailField(
            label: 'Contact Number',
            value: _editingDriver['contact_number'] ?? '',
            editable: _isEditing,
            onChanged: (v) => _editingDriver['contact_number'] = v,
          ),
          const SizedBox(height: 16),
          _buildDetailField(
            label: 'IC Number',
            value: _editingDriver['ic_number'] ?? '',
            editable: _isEditing,
            onChanged: (v) => _editingDriver['ic_number'] = v,
          ),
          const SizedBox(height: 16),
          _buildDetailField(
            label: 'License Number',
            value: _editingDriver['license_number'] ?? '',
            editable: _isEditing,
            onChanged: (v) => _editingDriver['license_number'] = v,
          ),
          const SizedBox(height: 16),
          _buildDetailField(
            label: 'Monthly Fee (RM)',
            value: (_editingDriver['monthly_fee'] ?? 0).toString(),
            editable: _isEditing,
            onChanged: (v) =>
                _editingDriver['monthly_fee'] = double.tryParse(v) ?? 0,
          ),
          const SizedBox(height: 16),
          if (_isEditing) ...[
            // Dropdown for bus selection
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
              onChanged: (v) {
                setState(() {
                  _selectedBusId = v == 'none' ? null : v;
                  _editingDriver['assigned_bus_id'] = _selectedBusId;
                });
              },
            ),
            const SizedBox(height: 16),
            // Schools selection with chips
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
                              _editingDriver['assigned_school_ids'] =
                                  _selectedSchoolIds;
                            });
                          },
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add School'),
                        onPressed: () async {
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
                              _editingDriver['assigned_school_ids'] =
                                  _selectedSchoolIds;
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
          ] else ...[
            _buildDetailField(
              label: 'Assigned Bus',
              value: _editingDriver['assigned_bus_id'] ?? 'Not assigned',
              editable: false,
            ),
            const SizedBox(height: 16),
            _buildDetailField(
              label: 'Assigned Schools',
              value: _buildSchoolsList(
                _editingDriver['assigned_school_ids'] ?? [],
              ),
              editable: false,
            ),
            const SizedBox(height: 16),
            if (_serviceArea != null)
              _buildDetailField(
                label: 'Service Area',
                value: '${_serviceArea!['radius_km']} km radius',
                editable: false,
              ),
          ],
          const SizedBox(height: 16),
          _buildDetailCard(
            'Verification Status',
            _editingDriver['is_verified'] == true ? '✅ Verified' : '⏳ Pending',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField({
    required String label,
    required String value,
    required bool editable,
    ValueChanged<String>? onChanged,
  }) {
    if (editable) {
      return TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: value),
        onChanged: onChanged,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSchoolsList(List<dynamic> schoolIds) {
    if (schoolIds.isEmpty) return 'None assigned';
    return schoolIds.join(', ');
  }

  Future<void> _saveChanges() async {
    try {
      await _service.updateDriver(widget.driverId, _editingDriver);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver details updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _TripsHistoryTab extends StatelessWidget {
  final String driverId;

  const _TripsHistoryTab({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('driver_id', isEqualTo: driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data!.docs;

        if (trips.isEmpty) {
          return const Center(child: Text('No trips history'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index].data() as Map<String, dynamic>;
            final tripId = trips[index].id;
            final routeType = trip['route_type'] ?? 'unknown';
            final createdAt = trip['created_at'] as Timestamp?;
            final passengers = trip['passengers'] as List? ?? [];
            final studentCount = passengers.length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.trip_origin, color: Colors.blue),
                ),
                title: Text('Route: ${_formatRouteType(routeType)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students: $studentCount',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (createdAt != null)
                      Text(
                        'Date: ${createdAt.toDate().toString().split('.').first}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showTripDetails(context, trip, tripId);
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatRouteType(String routeType) {
    switch (routeType) {
      case 'morning':
        return 'Morning';
      case 'primary_pm':
        return 'Primary PM';
      case 'secondary_pm':
        return 'Secondary PM';
      default:
        return routeType;
    }
  }

  void _showTripDetails(
    BuildContext context,
    Map<String, dynamic> trip,
    String tripId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTripInfoRow('Trip ID', tripId),
              _buildTripInfoRow(
                'Route Type',
                _formatRouteType(trip['route_type'] ?? ''),
              ),
              _buildTripInfoRow(
                'Students',
                (trip['passengers'] as List?)?.length.toString() ?? '0',
              ),
              _buildTripInfoRow('Status', trip['status'] ?? 'active'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StudentsListTab extends StatelessWidget {
  final String driverId;

  const _StudentsListTab({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .collection('students')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data!.docs;

        if (students.isEmpty) {
          return const Center(child: Text('No students assigned'));
        }

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _fetchSchoolDetails(
            students
                .map(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['school_id']
                          as String?,
                )
                .whereType<String>()
                .toList(),
          ),
          builder: (context, schoolSnapshot) {
            final schoolsMap = schoolSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index].data() as Map<String, dynamic>;
                final studentId = students[index].id;
                final studentName = student['child_name'] ?? 'Unnamed';
                final schoolId = student['school_id'] ?? '';
                final schoolData = schoolsMap[schoolId];
                final schoolName = schoolData?['name'] ?? 'Unknown School';
                final schoolType = schoolData?['type'] ?? 'primary';
                final tripType = student['trip_type'] ?? 'both';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withValues(alpha: 0.1),
                      child: Text(
                        studentName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.purple),
                      ),
                    ),
                    title: Text(studentName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School: $schoolName',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Type: ${_formatSchoolType(schoolType)} • ${_formatTripType(tripType)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.person),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchSchoolDetails(
    List<String> schoolIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};

    for (final schoolId in schoolIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
        if (doc.exists) {
          result[schoolId] = doc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Error fetching school $schoolId: $e');
      }
    }

    return result;
  }

  String _formatSchoolType(String type) {
    switch (type) {
      case 'primary':
        return 'Primary';
      case 'secondary':
        return 'Secondary';
      default:
        return type;
    }
  }

  String _formatTripType(String type) {
    switch (type) {
      case 'going':
        return 'Going Only';
      case 'return':
        return 'Return Only';
      case 'both':
        return 'Both';
      default:
        return type;
    }
  }
}

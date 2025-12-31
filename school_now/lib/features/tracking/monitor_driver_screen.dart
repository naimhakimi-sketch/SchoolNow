import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MonitorDriverScreen extends StatefulWidget {
  const MonitorDriverScreen({super.key});

  @override
  State<MonitorDriverScreen> createState() => _MonitorDriverScreenState();
}

class _MonitorDriverScreenState extends State<MonitorDriverScreen> {
  final MapController _mapController = MapController();
  String? _selectedDriverId;
  LatLng? _parentHomeLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParentLocation();
  }

  Future<void> _loadParentLocation() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final parentDoc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(userId)
          .get();

      if (parentDoc.exists) {
        final data = parentDoc.data();
        if (data != null &&
            data['pickup_lat'] != null &&
            data['pickup_lng'] != null) {
          setState(() {
            _parentHomeLocation = LatLng(
              data['pickup_lat'],
              data['pickup_lng'],
            );
            _isLoading = false;
          });
          // Center map on parent's home
          if (_parentHomeLocation != null) {
            _mapController.move(_parentHomeLocation!, 14);
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Driver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_parentHomeLocation != null) {
                _mapController.move(_parentHomeLocation!, 14);
              }
            },
            tooltip: 'Center to Home',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDriverSelector(),
                Expanded(
                  child: _selectedDriverId == null
                      ? const Center(child: Text('Select a driver to track'))
                      : _buildMap(),
                ),
                if (_selectedDriverId != null) _buildDriverInfo(),
              ],
            ),
    );
  }

  Widget _buildDriverSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where(
              'parent_id',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          // Get unique driver IDs from all students
          final driverIds = snapshot.data!.docs
              .map((doc) => doc['driver_id'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .toList();

          if (driverIds.isEmpty) {
            return const Text('No driver assigned to your children');
          }

          return FutureBuilder<List<DocumentSnapshot>>(
            future: Future.wait(
              driverIds.map(
                (id) => FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(id)
                    .get(),
              ),
            ),
            builder: (context, driversSnapshot) {
              if (!driversSnapshot.hasData) {
                return const CircularProgressIndicator();
              }

              return DropdownButtonFormField<String>(
                initialValue: _selectedDriverId,
                decoration: const InputDecoration(
                  labelText: 'Select Driver to Track',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: driversSnapshot.data!.map((driverDoc) {
                  final data = driverDoc.data() as Map<String, dynamic>?;
                  return DropdownMenuItem(
                    value: driverDoc.id,
                    child: Text(data?['name'] ?? 'Unknown Driver'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDriverId = value;
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(_selectedDriverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final driverData = snapshot.data!.data() as Map<String, dynamic>?;
        final currentLocation = driverData?['current_location'];

        LatLng? driverLocation;
        if (currentLocation != null &&
            currentLocation['latitude'] != null &&
            currentLocation['longitude'] != null) {
          driverLocation = LatLng(
            currentLocation['latitude'],
            currentLocation['longitude'],
          );
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _parentHomeLocation ?? const LatLng(24.7136, 46.6753),
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.school_now',
            ),
            MarkerLayer(
              markers: [
                // Parent's home marker
                if (_parentHomeLocation != null)
                  Marker(
                    point: _parentHomeLocation!,
                    width: 60,
                    height: 60,
                    child: const Column(
                      children: [
                        Icon(Icons.home, size: 40, color: Colors.blue),
                        Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Driver's current location marker
                if (driverLocation != null)
                  Marker(
                    point: driverLocation,
                    width: 60,
                    height: 60,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 40,
                          color: Colors.green,
                        ),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // Draw line between home and driver
            if (_parentHomeLocation != null && driverLocation != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_parentHomeLocation!, driverLocation],
                    strokeWidth: 3,
                    color: Colors.blue.withValues(alpha: 0.5),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(_selectedDriverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final driverData = snapshot.data!.data() as Map<String, dynamic>?;
          if (driverData == null) return const SizedBox.shrink();

          final currentLocation = driverData['current_location'];
          final isOnline = driverData['is_online'] == true;
          final speed = currentLocation?['speed'] ?? 0.0;
          final lastSeen = driverData['last_seen'] as Timestamp?;

          // Calculate distance to home
          double? distanceToHome;
          if (_parentHomeLocation != null &&
              currentLocation != null &&
              currentLocation['latitude'] != null &&
              currentLocation['longitude'] != null) {
            final driverLat = currentLocation['latitude'];
            final driverLng = currentLocation['longitude'];
            distanceToHome = const Distance().as(
              LengthUnit.Kilometer,
              _parentHomeLocation!,
              LatLng(driverLat, driverLng),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isOnline ? Colors.green : Colors.grey,
                    radius: 6,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    driverData['name'] ?? 'Unknown Driver',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoChip(
                    Icons.speed,
                    '${(speed * 3.6).toStringAsFixed(1)} km/h',
                    'Speed',
                  ),
                  if (distanceToHome != null)
                    _buildInfoChip(
                      Icons.location_on,
                      '${distanceToHome.toStringAsFixed(2)} km',
                      'Distance',
                    ),
                  if (lastSeen != null)
                    _buildInfoChip(
                      Icons.access_time,
                      _formatLastSeen(lastSeen),
                      'Last Update',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  String _formatLastSeen(Timestamp timestamp) {
    final now = DateTime.now();
    final lastSeen = timestamp.toDate();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/boarding_status.dart';
import '../../services/driver_service.dart';
import '../../services/live_location_service.dart';
import '../../services/notification_service.dart';
import '../../services/osrm_routing_service.dart';
import '../../services/student_management_service.dart';
import '../../services/trip_service.dart';
import 'qr_scanner_page.dart';

class DrivePage extends StatefulWidget {
  final String driverId;
  final bool isDemoMode;

  const DrivePage({
    super.key,
    required this.driverId,
    required this.isDemoMode,
  });

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  final _driverService = DriverService();
  final _tripService = TripService();
  final _locationService = LiveLocationService();
  final _studentService = StudentManagementService();
  final _routingService = OsrmRoutingService();
  final _notifications = NotificationService();
  final _mapController = MapController();

  bool _loadingAction = false;
  String? _error;

  String _selectedRouteType = 'morning';

  String? _routedKey;
  List<LatLng>? _routedPolyline;
  List<String> _routedSteps = const [];
  bool _routingInFlight = false;
  String? _routingStatusText;

  String _routeLabel(String routeType) {
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

  bool _isAfternoonRoute(String routeType) => routeType == 'primary_pm' || routeType == 'secondary_pm';

  bool _canStartRouteNow(String routeType, DateTime now) {
    // SRS FR-DR-3.4: Activation Time Restrictions
    // Morning: 6:00 AM, Primary PM: 1:30 PM, Secondary PM: 3:00 PM
    final start = switch (routeType) {
      'morning' => DateTime(now.year, now.month, now.day, 6, 0),
      'primary_pm' => DateTime(now.year, now.month, now.day, 13, 30),
      'secondary_pm' => DateTime(now.year, now.month, now.day, 15, 0),
      _ => DateTime(now.year, now.month, now.day, 6, 0),
    };
    return !now.isBefore(start);
  }

  Future<void> _launchCall(String phoneNumber) async {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: trimmed);
    await launchUrl(uri);
  }

  Future<void> _startTrip() async {
    setState(() {
      _loadingAction = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      if (!_canStartRouteNow(_selectedRouteType, now)) {
        throw Exception('Service can only be activated at ${_routeLabel(_selectedRouteType)} start time.');
      }

      final todayYmd = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final driver = await _driverService.getDriver(widget.driverId);
      final vehicleId = (driver?['transport_number'] ?? 'vehicle_unknown').toString();

      // SRS FR-DR-3.2: students scheduled for current day.
      // For MVP we treat all approved students under this driver as scheduled.
      final studentIds = await _studentService.getApprovedStudentIds(widget.driverId);

      // Optional parent attendance override (SRS FR-PA-5.6).
      final absentIds = <String>[];
      final studentsSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .collection('students')
          .get();
      for (final d in studentsSnap.docs) {
        final data = d.data();
        final override = (data['attendance_override'] ?? '').toString();
        final date = (data['attendance_date_ymd'] ?? '').toString();
        if (override == 'absent' && date == todayYmd) {
          absentIds.add(d.id);
        }
      }

      final tripId = await _tripService.createTrip(
        driverId: widget.driverId,
        vehicleId: vehicleId,
        routeId: 'route_default',
        routeType: _selectedRouteType,
        studentIds: studentIds,
      );
      await _tripService.startTrip(tripId);

      for (final id in absentIds) {
        if (!studentIds.contains(id)) continue;
        await _tripService.upsertPassengerStatus(tripId, id, BoardingStatus.absent);
      }
      await _locationService.startSharing(tripId: tripId, driverId: widget.driverId);
    } catch (e) {
      setState(() {
        _error = 'Failed to start trip: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = false;
        });
      }
    }
  }

  Future<void> _endTrip(String tripId) async {
    setState(() {
      _loadingAction = true;
      _error = null;
    });

    try {
      await _locationService.stopSharing();
      await _tripService.endTrip(tripId);
    } catch (e) {
      setState(() {
        _error = 'Failed to end trip: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = false;
        });
      }
    }
  }

  Future<void> _scanStudentQr({
    required String tripId,
  }) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(
          onCode: (code) async {
            // For now we expect QR to encode the studentId.
            final studentId = code;
            await _tripService.upsertPassengerStatus(tripId, studentId, BoardingStatus.boarded);

            // Notify parent (best-effort).
            try {
              final studentSnap = await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(widget.driverId)
                  .collection('students')
                  .doc(studentId)
                  .get();
              final parentId = (studentSnap.data()?['parent_id'] ?? '').toString();
              final studentName = (studentSnap.data()?['student_name'] ?? studentId).toString();
              if (parentId.isNotEmpty) {
                await _notifications.createUnique(
                  notificationId: 'boarding_${tripId}_${studentId}_boarded',
                  userId: parentId,
                  type: 'boarding',
                  message: '$studentName: Boarded',
                );
              }
            } catch (_) {}

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Marked boarded: $studentId')),
              );
            }
          },
        ),
      ),
    );
  }

  void _focusNextStop(LatLng destination) {
    // In-app "navigation": center the map on the next stop.
    _mapController.move(destination, 16);
  }

  String _makeRouteKey(String routeType, List<LatLng> points) {
    final b = StringBuffer(routeType);
    for (final p in points) {
      // rounding helps avoid churn from tiny float differences
      b.write('|${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}');
    }
    return b.toString();
  }

  void _ensureRoutedPolyline(String routeType, List<LatLng> stops) {
    if (stops.length < 2) return;
    final key = _makeRouteKey(routeType, stops);
    if (_routedKey == key) return;
    if (_routingInFlight) return;

    setState(() {
      _routingInFlight = true;
      _routingStatusText = 'Routing…';
    });
    _routingService.routeDrivingWithSteps(stops, includeSteps: true).then((route) {
      if (!mounted) return;
      setState(() {
        _routedKey = key;
        // If routing fails silently (empty), we keep fallback straight polyline.
        final routed = route?.geometry ?? const <LatLng>[];
        final ok = routed.length >= 2;
        _routedPolyline = ok ? routed : null;
        _routedSteps = (ok ? (route?.steps ?? const <String>[]) : const <String>[]);
        _routingStatusText = ok ? 'Routing: OSRM (roads)' : 'Routing: straight line (no route)';
      });
    }).catchError((_) {
      // Network/service issues should not break the UI.
      if (!mounted) return;
      setState(() {
        _routedKey = key;
        _routedPolyline = null;
        _routedSteps = const [];
        _routingStatusText = 'Routing: straight line (OSRM unavailable)';
      });
    }).whenComplete(() {
      _routingInFlight = false;
    });
  }

  LatLng? _latLngFromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _driverHome(Map<String, dynamic>? driverData) {
    final home = (driverData?['home_location'] as Map?)?.cast<String, dynamic>();
    return _latLngFromMap(home);
  }

  LatLng? _schoolPoint(Map<String, dynamic>? driverData) {
    final serviceArea = (driverData?['service_area'] as Map?)?.cast<String, dynamic>();
    final lat = (serviceArea?['school_lat'] as num?)?.toDouble();
    final lng = (serviceArea?['school_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  // SRS routing rule: sort stops by distance from current origin.
  List<Map<String, dynamic>> _sortStopsByNearestNeighbor({
    required LatLng origin,
    required List<Map<String, dynamic>> stops,
  }) {
    final dist = const Distance();
    final remaining = List<Map<String, dynamic>>.from(stops);
    final ordered = <Map<String, dynamic>>[];
    var current = origin;
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final pa = a['point'] as LatLng;
        final pb = b['point'] as LatLng;
        final da = dist(current, pa);
        final db = dist(current, pb);
        return da.compareTo(db);
      });
      final next = remaining.removeAt(0);
      ordered.add(next);
      current = next['point'] as LatLng;
    }
    return ordered;
  }

  List<LatLng> _buildRoutePolyline({
    required String routeType,
    required Map<String, dynamic>? driverData,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
  }) {
    final home = _driverHome(driverData);
    final school = _schoolPoint(driverData);
    if (home == null || school == null) return const [];

    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson((p['status'] ?? 'not_boarded').toString());
    }

    LatLng? pickupOf(String studentId) {
      final data = studentById[studentId];
      final loc = (data?['pickup_location'] as Map?)?.cast<String, dynamic>();
      return _latLngFromMap(loc);
    }

    final isAfternoon = _isAfternoonRoute(routeType);
    final studentIds = studentById.keys.toList();

    if (!isAfternoon) {
      // Morning: home -> remaining pickups -> school
      final pendingPickups = <Map<String, dynamic>>[];
      for (final id in studentIds) {
        final s = statusOf(id);
        if (s == BoardingStatus.boarded || s == BoardingStatus.absent || s == BoardingStatus.alighted) continue;
        final p = pickupOf(id);
        if (p != null) {
          pendingPickups.add({'student_id': id, 'point': p});
        }
      }

      final ordered = pendingPickups.isEmpty ? const <Map<String, dynamic>>[] : _sortStopsByNearestNeighbor(origin: home, stops: pendingPickups);
      return [
        home,
        ...ordered.map((e) => e['point'] as LatLng),
        school,
      ];
    }

    // Afternoon: school -> remaining dropoffs -> home
    final remainingDropoffs = <Map<String, dynamic>>[];
    for (final id in studentIds) {
      final s = statusOf(id);
      if (s == BoardingStatus.absent || s == BoardingStatus.alighted) continue;
      final p = pickupOf(id);
      if (p != null) {
        remainingDropoffs.add({'student_id': id, 'point': p});
      }
    }
    final ordered = remainingDropoffs.isEmpty ? const <Map<String, dynamic>>[] : _sortStopsByNearestNeighbor(origin: school, stops: remainingDropoffs);
    return [
      school,
      ...ordered.map((e) => e['point'] as LatLng),
      home,
    ];
  }

  LatLng? _nextDestination({
    required String routeType,
    required Map<String, dynamic>? driverData,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
  }) {
    final home = _driverHome(driverData);
    final school = _schoolPoint(driverData);
    if (home == null || school == null) return null;

    final isAfternoon = _isAfternoonRoute(routeType);

    // Map passenger statuses.
    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson((p['status'] ?? 'not_boarded').toString());
    }

    LatLng? pickupOf(String studentId) {
      final data = studentById[studentId];
      final loc = (data?['pickup_location'] as Map?)?.cast<String, dynamic>();
      return _latLngFromMap(loc);
    }

    final studentIds = studentById.keys.toList();

    if (!isAfternoon) {
      // Morning: home -> pickups -> school
      final pendingPickups = <Map<String, dynamic>>[];
      for (final id in studentIds) {
        final s = statusOf(id);
        if (s == BoardingStatus.boarded || s == BoardingStatus.absent || s == BoardingStatus.alighted) continue;
        final p = pickupOf(id);
        if (p != null) {
          pendingPickups.add({'student_id': id, 'point': p});
        }
      }
      if (pendingPickups.isNotEmpty) {
        final ordered = _sortStopsByNearestNeighbor(origin: home, stops: pendingPickups);
        return ordered.first['point'] as LatLng;
      }
      return school;
    }

    // Afternoon: school -> dropoffs -> home
    final stillAtSchool = studentIds.any((id) {
      final s = statusOf(id);
      return s == BoardingStatus.notBoarded;
    });
    if (stillAtSchool) {
      return school;
    }

    final pendingDropoffs = <Map<String, dynamic>>[];
    for (final id in studentIds) {
      final s = statusOf(id);
      // After school, students should be boarded (in van) then alighted at home.
      if (s == BoardingStatus.alighted || s == BoardingStatus.absent) continue;
      final p = pickupOf(id);
      if (p != null) {
        pendingDropoffs.add({'student_id': id, 'point': p});
      }
    }
    if (pendingDropoffs.isNotEmpty) {
      final ordered = _sortStopsByNearestNeighbor(origin: school, stops: pendingDropoffs);
      return ordered.first['point'] as LatLng;
    }

    return home;
  }

  Widget _buildRouteMap({
    required Map<String, dynamic>? driverData,
    required String routeType,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
  }) {
    final serviceArea = (driverData?['service_area'] as Map?)?.cast<String, dynamic>();
    final schoolLat = (serviceArea?['school_lat'] as num?)?.toDouble();
    final schoolLng = (serviceArea?['school_lng'] as num?)?.toDouble();
    final radiusKm = (serviceArea?['radius_km'] as num?)?.toDouble();

    LatLng center = const LatLng(0, 0);
    double? radiusMeters;
    if (schoolLat != null && schoolLng != null && radiusKm != null) {
      center = LatLng(schoolLat, schoolLng);
      radiusMeters = radiusKm * 1000;
    }

    final hasArea = radiusMeters != null;
    final markers = <Marker>[];

    final stopPolylinePoints = _buildRoutePolyline(
      routeType: routeType,
      driverData: driverData,
      passengers: passengers,
      studentById: studentById,
    );

    // Kick off routing to get a road-following polyline.
    // This is intentionally "fire-and-forget" so map rendering stays synchronous.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureRoutedPolyline(routeType, stopPolylinePoints);
    });

    final routed = _routedKey == _makeRouteKey(routeType, stopPolylinePoints) ? _routedPolyline : null;
    final polylinePoints = (routed != null && routed.length >= 2) ? routed : stopPolylinePoints;

    final school = _schoolPoint(driverData);
    if (school != null) {
      markers.add(
        Marker(
          point: school,
          width: 44,
          height: 44,
          child: const Icon(Icons.school, color: Colors.blue, size: 40),
        ),
      );
    }

    final home = _driverHome(driverData);
    if (home != null) {
      markers.add(
        Marker(
          point: home,
          width: 40,
          height: 40,
          child: const Icon(Icons.home, color: Colors.black87, size: 34),
        ),
      );
    }

    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson((p['status'] ?? 'not_boarded').toString());
    }

    // SRS FR-DR-3.10: remove pickup pin once boarded.
    for (final entry in studentById.entries) {
      final studentId = entry.key;
      final student = entry.value;
      final pickup = _latLngFromMap((student['pickup_location'] as Map?)?.cast<String, dynamic>());
      if (pickup == null) continue;

      final s = statusOf(studentId);
      final isAfternoon = _isAfternoonRoute(routeType);

      bool show;
      if (!isAfternoon) {
        show = !(s == BoardingStatus.boarded || s == BoardingStatus.absent || s == BoardingStatus.alighted);
      } else {
        // Afternoon: show dropoff pins until arrived/absent.
        show = !(s == BoardingStatus.alighted || s == BoardingStatus.absent);
      }

      if (!show) continue;

      markers.add(
        Marker(
          point: pickup,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 36),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasArea ? 13 : 2,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'school_now_driver',
            ),
            if (polylinePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            if (hasArea)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: radiusMeters,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderColor: Colors.blue.withValues(alpha: 0.6),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  bool _allPickedUpOrAbsent({
    required List<Map<String, dynamic>> passengers,
    required Iterable<String> studentIds,
  }) {
    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson((p['status'] ?? 'not_boarded').toString());
    }

    for (final id in studentIds) {
      final s = statusOf(id);
      if (s == BoardingStatus.notBoarded) return false;
    }
    return true;
  }

  bool _canEndSession({
    required List<Map<String, dynamic>> passengers,
    required Iterable<String> studentIds,
  }) {
    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson((p['status'] ?? 'not_boarded').toString());
    }

    for (final id in studentIds) {
      final s = statusOf(id);
      if (s != BoardingStatus.alighted && s != BoardingStatus.absent) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _driverService.streamDriver(widget.driverId),
          builder: (context, driverSnap) {
            final driverData = driverSnap.data?.data();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _studentService.streamApprovedStudents(widget.driverId),
              builder: (context, studentsSnap) {
                final studentDocs = studentsSnap.data?.docs ?? const [];
                final studentById = {
                  for (final d in studentDocs) d.id: d.data(),
                };

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                  stream: _tripService.streamActiveTripForDriver(widget.driverId),
                  builder: (context, tripSnap) {
                    final tripDoc = tripSnap.data;
                    final trip = tripDoc?.data();

                    final tripId = tripDoc?.id;
                    final status = (trip?['status'] ?? '').toString();
                    final passengers = (trip?['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                    final routeType = (trip?['route_type'] ?? _selectedRouteType).toString();
                    final studentIds = studentById.keys;

                    final orderedStudentIds = studentById.entries.toList()
                      ..sort((a, b) {
                        final an = (a.value['student_name'] ?? a.key).toString().toLowerCase();
                        final bn = (b.value['student_name'] ?? b.key).toString().toLowerCase();
                        return an.compareTo(bn);
                      });

                    final nextDest = tripId == null
                        ? null
                        : _nextDestination(
                            routeType: routeType,
                            driverData: driverData,
                            passengers: passengers,
                            studentById: studentById,
                          );

                    final isAfternoon = _isAfternoonRoute(routeType);
                    final canArriveAtSchool = tripId != null && !isAfternoon && _allPickedUpOrAbsent(
                          passengers: passengers,
                          studentIds: studentIds,
                        );

                    final canEnd = tripId != null && _canEndSession(passengers: passengers, studentIds: studentIds);

                    return ListView(
                      children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Drive',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (widget.isDemoMode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRouteMap(
                      driverData: driverData,
                      routeType: tripId == null ? _selectedRouteType : routeType,
                      passengers: passengers,
                      studentById: studentById,
                    ),
                    if (_routingStatusText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _routingStatusText!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_routedSteps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        child: ExpansionTile(
                          title: const Text('Turn-by-turn instructions'),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: [
                            for (final s in _routedSteps.take(8))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(s, style: Theme.of(context).textTheme.bodySmall),
                              ),
                            if (_routedSteps.length > 8)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('…'),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    if (tripId == null)
                      Row(
                        children: [
                          const Text('Route:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedRouteType,
                            items: const [
                              DropdownMenuItem(value: 'morning', child: Text('Morning')),
                              DropdownMenuItem(value: 'primary_pm', child: Text('Primary PM')),
                              DropdownMenuItem(value: 'secondary_pm', child: Text('Secondary PM')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _selectedRouteType = v;
                              });
                            },
                          ),
                        ],
                      )
                    else
                      Text('Route: ${_routeLabel(routeType)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),

                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                      ),

                    const SizedBox(height: 12),
                    if (tripId == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loadingAction ? null : _startTrip,
                          icon: const Icon(Icons.play_arrow),
                          label: _loadingAction
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Start Service'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_loadingAction || !canEnd) ? null : () => _endTrip(tripId),
                              icon: const Icon(Icons.stop),
                              label: _loadingAction
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(canEnd ? 'End Service' : 'End (Not ready)'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _loadingAction ? null : () => _scanStudentQr(tripId: tripId),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan'),
                          ),
                        ],
                      ),

                    if (tripId != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_loadingAction || nextDest == null)
                                  ? null
                                  : () => _focusNextStop(nextDest),
                              icon: const Icon(Icons.navigation),
                              label: const Text('Navigate to Next Stop'),
                            ),
                          ),
                          if (canArriveAtSchool) ...[
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _loadingAction
                                  ? null
                                  : () async {
                                      setState(() {
                                        _loadingAction = true;
                                        _error = null;
                                      });
                                      try {
                                        await _tripService.markAllArrivedAtSchool(tripId);
                                      } catch (e) {
                                        setState(() {
                                          _error = 'Failed to mark arrived: $e';
                                        });
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _loadingAction = false;
                                          });
                                        }
                                      }
                                    },
                              child: const Text('Arrived at School'),
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    if (tripId != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Session QR', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Center(
                                child: QrImageView(
                                  data: tripId,
                                  size: 160,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Trip ID: $tripId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text('Status: $status', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Boarding Status', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (tripId == null)
                              Text(
                                studentById.isEmpty
                                    ? 'No students under service.'
                                    : 'No active service. Start service to begin.',
                              )
                            else if (passengers.isEmpty && studentById.isEmpty)
                              const Text('No students assigned to this trip yet.')
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: studentById.isEmpty ? passengers.length : studentById.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                      final studentId = studentById.isEmpty
                                          ? (passengers[i]['student_id'] ?? '').toString()
                                          : orderedStudentIds[i].key;

                                      final student = studentById[studentId];
                                      final studentName = (student?['student_name'] ?? studentId).toString();
                                      final parentPhone = (student?['parent_phone'] ?? '').toString();

                                      final p = passengers.firstWhere(
                                        (x) => (x['student_id'] ?? '').toString() == studentId,
                                        orElse: () => const <String, dynamic>{},
                                      );
                                      final statusStr = (p['status'] ?? 'not_boarded').toString();
                                      final statusEnum = BoardingStatusCodec.fromJson(statusStr);

                                      final arrivedLabel = isAfternoon ? 'Arrived (Home)' : 'Arrived (School)';

                                      return ListTile(
                                        isThreeLine: true,
                                        title: Text(studentName, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        subtitle: Text('Status: $statusStr', maxLines: 2, overflow: TextOverflow.ellipsis),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (v) async {
                                            final next = BoardingStatusCodec.fromJson(v);
                                            await _tripService.updatePassengerStatus(tripId, studentId, next);

                                            // Notify parent (best-effort).
                                            try {
                                              final studentSnap = await FirebaseFirestore.instance
                                                  .collection('drivers')
                                                  .doc(widget.driverId)
                                                  .collection('students')
                                                  .doc(studentId)
                                                  .get();
                                              final parentId = (studentSnap.data()?['parent_id'] ?? '').toString();
                                              final studentName = (studentSnap.data()?['student_name'] ?? studentId).toString();
                                              if (parentId.isNotEmpty) {
                                                final label = switch (next) {
                                                  BoardingStatus.notBoarded => 'Not Boarded',
                                                  BoardingStatus.boarded => 'Boarded',
                                                  BoardingStatus.alighted => 'Arrived',
                                                  BoardingStatus.absent => 'Absent',
                                                };
                                                await _notifications.createUnique(
                                                  notificationId: 'boarding_${tripId}_${studentId}_${BoardingStatusCodec.toJson(next)}',
                                                  userId: parentId,
                                                  type: 'boarding',
                                                  message: '$studentName: $label',
                                                );
                                              }
                                            } catch (_) {}
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(value: 'not_boarded', child: Text('Not Boarded')),
                                            const PopupMenuItem(value: 'boarded', child: Text('Boarded')),
                                            PopupMenuItem(value: 'alighted', child: Text(arrivedLabel)),
                                            const PopupMenuItem(value: 'absent', child: Text('Absent')),
                                          ],
                                        ),
                                        onTap: parentPhone.isEmpty ? null : () => _launchCall(parentPhone),
                                        leading: Icon(
                                          statusEnum == BoardingStatus.boarded
                                              ? Icons.check_circle
                                              : statusEnum == BoardingStatus.alighted
                                                  ? Icons.flag
                                                  : statusEnum == BoardingStatus.absent
                                                      ? Icons.remove_circle
                                                      : Icons.radio_button_unchecked,
                                          color: statusEnum == BoardingStatus.boarded
                                              ? Colors.green
                                              : statusEnum == BoardingStatus.alighted
                                                  ? Colors.blue
                                                  : statusEnum == BoardingStatus.absent
                                                      ? Colors.orange
                                                      : Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

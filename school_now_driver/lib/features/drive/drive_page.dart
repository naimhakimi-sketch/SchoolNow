import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
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
  final Location _deviceLocation = Location();

  LatLng? _currentRouteStart;
  bool _loadingCurrentRouteStart = false;

  String _todayYmd() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _loadingAction = false;
  String? _error;
  bool _showStudentList = false;
  bool _showQrOverlay = false;

  String _selectedRouteType = 'morning';

  String? _routedKey;
  List<LatLng>? _routedPolyline;
  bool _routingInFlight = false;

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

  bool _isAfternoonRoute(String routeType) =>
      routeType == 'primary_pm' || routeType == 'secondary_pm';

  // ignore: unused_element
  bool _canStartRouteNow(String routeType, DateTime now) {
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

  Future<void> _centerOnMyLocation() async {
    try {
      bool serviceEnabled = await _deviceLocation.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _deviceLocation.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permission = await _deviceLocation.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _deviceLocation.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      final loc = await _deviceLocation.getLocation();
      final lat = (loc.latitude ?? 0).toDouble();
      final lng = (loc.longitude ?? 0).toDouble();
      if (!mounted) return;

      _mapController.move(LatLng(lat, lng), 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> _ensureCurrentRouteStartLoaded() async {
    if (_currentRouteStart != null) return;
    if (_loadingCurrentRouteStart) return;
    _loadingCurrentRouteStart = true;

    try {
      bool serviceEnabled = await _deviceLocation.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _deviceLocation.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permission = await _deviceLocation.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _deviceLocation.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      final loc = await _deviceLocation.getLocation();
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null) return;

      if (!mounted) return;
      setState(() {
        _currentRouteStart = LatLng(lat.toDouble(), lng.toDouble());
      });
    } catch (_) {
      // Best-effort: if we can't read GPS, we fall back to home/school.
    } finally {
      _loadingCurrentRouteStart = false;
    }
  }

  Future<void> _startTrip() async {
    setState(() {
      _loadingAction = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      // Time-based restriction removed for easier testing

      final todayYmd =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final driver = await _driverService.getDriver(widget.driverId);
      final vehicleId = (driver?['transport_number'] ?? 'vehicle_unknown')
          .toString();

      final studentIds = await _studentService.getApprovedStudentIds(
        widget.driverId,
      );

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
        await _tripService.upsertPassengerStatus(
          tripId,
          id,
          BoardingStatus.absent,
        );
      }
      await _locationService.startSharing(
        tripId: tripId,
        driverId: widget.driverId,
      );
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

  Future<void> _scanStudentQr({required String tripId}) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(
          onCode: (code) async {
            final studentId = code;
            await _tripService.upsertPassengerStatus(
              tripId,
              studentId,
              BoardingStatus.boarded,
            );

            try {
              final studentSnap = await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(widget.driverId)
                  .collection('students')
                  .doc(studentId)
                  .get();
              final parentId = (studentSnap.data()?['parent_id'] ?? '')
                  .toString();
              final studentName =
                  (studentSnap.data()?['student_name'] ?? studentId).toString();
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
    _mapController.move(destination, 16);
  }

  String _makeRouteKey(String routeType, List<LatLng> points) {
    final b = StringBuffer(routeType);
    for (final p in points) {
      b.write(
        '|${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}',
      );
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
    });
    _routingService
        .routeDrivingWithSteps(stops, includeSteps: true)
        .then((route) {
          if (!mounted) return;
          setState(() {
            _routedKey = key;
            final routed = route?.geometry ?? const <LatLng>[];
            final ok = routed.length >= 2;
            _routedPolyline = ok ? routed : null;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _routedKey = key;
            _routedPolyline = null;
          });
        })
        .whenComplete(() {
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
    final home = (driverData?['home_location'] as Map?)
        ?.cast<String, dynamic>();
    return _latLngFromMap(home);
  }

  LatLng? _schoolPoint(Map<String, dynamic>? driverData) {
    final serviceArea = (driverData?['service_area'] as Map?)
        ?.cast<String, dynamic>();
    final lat = (serviceArea?['school_lat'] as num?)?.toDouble();
    final lng = (serviceArea?['school_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

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
    LatLng? currentPosition,
  }) {
    final home = _driverHome(driverData);
    final school = _schoolPoint(driverData);
    if (home == null || school == null) return const [];

    final start = currentPosition ?? home;

    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson(
        (p['status'] ?? 'not_boarded').toString(),
      );
    }

    LatLng? pickupOf(String studentId) {
      final data = studentById[studentId];
      final loc = (data?['pickup_location'] as Map?)?.cast<String, dynamic>();
      return _latLngFromMap(loc);
    }

    final isAfternoon = _isAfternoonRoute(routeType);
    final studentIds = studentById.keys.toList();

    if (!isAfternoon) {
      final pendingPickups = <Map<String, dynamic>>[];
      for (final id in studentIds) {
        final s = statusOf(id);
        if (s == BoardingStatus.boarded ||
            s == BoardingStatus.absent ||
            s == BoardingStatus.alighted) {
          continue;
        }
        final p = pickupOf(id);
        if (p != null) {
          pendingPickups.add({'student_id': id, 'point': p});
        }
      }

      final ordered = pendingPickups.isEmpty
          ? const <Map<String, dynamic>>[]
          : _sortStopsByNearestNeighbor(origin: start, stops: pendingPickups);
      return [start, ...ordered.map((e) => e['point'] as LatLng), school];
    }

    final remainingDropoffs = <Map<String, dynamic>>[];
    for (final id in studentIds) {
      final s = statusOf(id);
      if (s == BoardingStatus.absent || s == BoardingStatus.alighted) continue;
      final p = pickupOf(id);
      if (p != null) {
        remainingDropoffs.add({'student_id': id, 'point': p});
      }
    }
    final ordered = remainingDropoffs.isEmpty
        ? const <Map<String, dynamic>>[]
        : _sortStopsByNearestNeighbor(origin: school, stops: remainingDropoffs);
    // Afternoon flow: driver can start anywhere, but first stop is school.
    // Last destination is home.
    return [start, school, ...ordered.map((e) => e['point'] as LatLng), home];
  }

  LatLng? _nextDestination({
    required String routeType,
    required Map<String, dynamic>? driverData,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
    LatLng? currentPosition,
  }) {
    final home = _driverHome(driverData);
    final school = _schoolPoint(driverData);
    if (home == null || school == null) return null;

    final start = currentPosition ?? home;

    final isAfternoon = _isAfternoonRoute(routeType);

    BoardingStatus statusOf(String studentId) {
      final p = passengers.firstWhere(
        (x) => (x['student_id'] ?? '').toString() == studentId,
        orElse: () => const <String, dynamic>{},
      );
      return BoardingStatusCodec.fromJson(
        (p['status'] ?? 'not_boarded').toString(),
      );
    }

    LatLng? pickupOf(String studentId) {
      final data = studentById[studentId];
      final loc = (data?['pickup_location'] as Map?)?.cast<String, dynamic>();
      return _latLngFromMap(loc);
    }

    final studentIds = studentById.keys.toList();

    if (!isAfternoon) {
      final pendingPickups = <Map<String, dynamic>>[];
      for (final id in studentIds) {
        final s = statusOf(id);
        if (s == BoardingStatus.boarded ||
            s == BoardingStatus.absent ||
            s == BoardingStatus.alighted) {
          continue;
        }
        final p = pickupOf(id);
        if (p != null) {
          pendingPickups.add({'student_id': id, 'point': p});
        }
      }
      if (pendingPickups.isNotEmpty) {
        final ordered = _sortStopsByNearestNeighbor(
          origin: start,
          stops: pendingPickups,
        );
        return ordered.first['point'] as LatLng;
      }
      return school;
    }

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
      if (s == BoardingStatus.alighted || s == BoardingStatus.absent) continue;
      final p = pickupOf(id);
      if (p != null) {
        pendingDropoffs.add({'student_id': id, 'point': p});
      }
    }
    if (pendingDropoffs.isNotEmpty) {
      final ordered = _sortStopsByNearestNeighbor(
        origin: school,
        stops: pendingDropoffs,
      );
      return ordered.first['point'] as LatLng;
    }

    return home;
  }

  Widget _buildFullScreenMap({
    required Map<String, dynamic>? driverData,
    required String routeType,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCurrentRouteStartLoaded();
    });
    final serviceArea = (driverData?['service_area'] as Map?)
        ?.cast<String, dynamic>();
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
      currentPosition: _currentRouteStart,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureRoutedPolyline(routeType, stopPolylinePoints);
    });

    final routed = _routedKey == _makeRouteKey(routeType, stopPolylinePoints)
        ? _routedPolyline
        : null;
    final polylinePoints = (routed != null && routed.length >= 2)
        ? routed
        : stopPolylinePoints;

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
      return BoardingStatusCodec.fromJson(
        (p['status'] ?? 'not_boarded').toString(),
      );
    }

    for (final entry in studentById.entries) {
      final studentId = entry.key;
      final student = entry.value;
      final pickup = _latLngFromMap(
        (student['pickup_location'] as Map?)?.cast<String, dynamic>(),
      );
      if (pickup == null) continue;

      final s = statusOf(studentId);
      final isAfternoon = _isAfternoonRoute(routeType);

      bool show;
      if (!isAfternoon) {
        show =
            !(s == BoardingStatus.boarded ||
                s == BoardingStatus.absent ||
                s == BoardingStatus.alighted);
      } else {
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

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasArea ? 13 : 2,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
        Positioned(
          right: 10,
          bottom: 10,
          child: FloatingActionButton.small(
            heroTag: 'drive_center',
            onPressed: _centerOnMyLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
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
      return BoardingStatusCodec.fromJson(
        (p['status'] ?? 'not_boarded').toString(),
      );
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
      return BoardingStatusCodec.fromJson(
        (p['status'] ?? 'not_boarded').toString(),
      );
    }

    for (final id in studentIds) {
      final s = statusOf(id);
      if (s != BoardingStatus.alighted && s != BoardingStatus.absent) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverService.streamDriver(widget.driverId),
      builder: (context, driverSnap) {
        final driverData = driverSnap.data?.data();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _studentService.streamApprovedStudents(widget.driverId),
          builder: (context, studentsSnap) {
            final studentDocs = studentsSnap.data?.docs ?? const [];
            final studentById = {for (final d in studentDocs) d.id: d.data()};

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: _tripService.streamActiveTripForDriver(widget.driverId),
              builder: (context, tripSnap) {
                final tripDoc = tripSnap.data;
                final trip = tripDoc?.data();

                final tripId = tripDoc?.id;
                final passengers =
                    (trip?['passengers'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    const [];
                final routeType = (trip?['route_type'] ?? _selectedRouteType)
                    .toString();
                final studentIds = studentById.keys;

                final orderedStudentIds = studentById.entries.toList()
                  ..sort((a, b) {
                    final an = (a.value['student_name'] ?? a.key)
                        .toString()
                        .toLowerCase();
                    final bn = (b.value['student_name'] ?? b.key)
                        .toString()
                        .toLowerCase();
                    return an.compareTo(bn);
                  });

                final nextDest = tripId == null
                    ? null
                    : _nextDestination(
                        routeType: routeType,
                        driverData: driverData,
                        passengers: passengers,
                        studentById: studentById,
                        currentPosition: _currentRouteStart,
                      );

                final isAfternoon = _isAfternoonRoute(routeType);
                final canArriveAtSchool =
                    tripId != null &&
                    !isAfternoon &&
                    _allPickedUpOrAbsent(
                      passengers: passengers,
                      studentIds: studentIds,
                    );

                final canEnd =
                    tripId != null &&
                    _canEndSession(
                      passengers: passengers,
                      studentIds: studentIds,
                    );

                return Scaffold(
                  body: Stack(
                    children: [
                      // Full screen map
                      _buildFullScreenMap(
                        driverData: driverData,
                        routeType: tripId == null
                            ? _selectedRouteType
                            : routeType,
                        passengers: passengers,
                        studentById: studentById,
                      ),

                      // Top overlay - Demo badge and route info
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (widget.isDemoMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'DEMO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      tripId == null
                                          ? _routeLabel(_selectedRouteType)
                                          : _routeLabel(routeType),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom overlay - Main controls
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Drag handle
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Error message
                                      if (_error != null) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // Route selector (when no active trip)
                                      if (tripId == null) ...[
                                        Row(
                                          children: [
                                            const Text(
                                              'Route:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: DropdownButton<String>(
                                                value: _selectedRouteType,
                                                isExpanded: true,
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'morning',
                                                    child: Text('Morning'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'primary_pm',
                                                    child: Text('Primary PM'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'secondary_pm',
                                                    child: Text('Secondary PM'),
                                                  ),
                                                ],
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  setState(() {
                                                    _selectedRouteType = v;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // Main action buttons
                                      if (tripId == null)
                                        SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _loadingAction
                                                ? null
                                                : _startTrip,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: _loadingAction
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.play_arrow),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Start Service',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        )
                                      else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: SizedBox(
                                                height: 50,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      (_loadingAction ||
                                                          !canEnd)
                                                      ? null
                                                      : () => _endTrip(tripId),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: _loadingAction
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        )
                                                      : Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            const Icon(
                                                              Icons.stop,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              canEnd
                                                                  ? 'End Service'
                                                                  : 'End (Not ready)',
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 50,
                                              child: ElevatedButton(
                                                onPressed: _loadingAction
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _showQrOverlay =
                                                              !_showQrOverlay;
                                                        });
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  side: BorderSide(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                ),
                                                child: const Icon(
                                                  Icons.qr_code_scanner,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 44,
                                                child: OutlinedButton(
                                                  onPressed:
                                                      (_loadingAction ||
                                                          nextDest == null)
                                                      ? null
                                                      : () => _focusNextStop(
                                                          nextDest,
                                                        ),
                                                  style: OutlinedButton.styleFrom(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.navigation,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Navigate to Next',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (canArriveAtSchool) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 44,
                                                child: ElevatedButton(
                                                  onPressed: _loadingAction
                                                      ? null
                                                      : () async {
                                                          setState(() {
                                                            _loadingAction =
                                                                true;
                                                            _error = null;
                                                          });
                                                          try {
                                                            await _tripService
                                                                .markAllArrivedAtSchool(
                                                                  tripId,
                                                                );
                                                          } catch (e) {
                                                            setState(() {
                                                              _error =
                                                                  'Failed to mark arrived: $e';
                                                            });
                                                          } finally {
                                                            if (mounted) {
                                                              setState(() {
                                                                _loadingAction =
                                                                    false;
                                                              });
                                                            }
                                                          }
                                                        },
                                                  style: ElevatedButton.styleFrom(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Arrived',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                _showStudentList =
                                                    !_showStudentList;
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.people,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Student List (${studentById.length})',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  _showStudentList
                                                      ? Icons
                                                            .keyboard_arrow_down
                                                      : Icons.keyboard_arrow_up,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // QR overlay
                      if (_showQrOverlay && tripId != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          top: MediaQuery.of(context).size.height * 0.25,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showQrOverlay = false;
                              });
                            },
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: GestureDetector(
                                onTap: () {},
                                child: Container(
                                  margin: const EdgeInsets.only(top: 60),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Trip QR Code',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () {
                                                setState(() {
                                                  _showQrOverlay = false;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Students can scan this QR code',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: QrImageView(
                                                  data: tripId,
                                                  version: QrVersions.auto,
                                                  size: 250,
                                                  backgroundColor: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                'Trip ID: $tripId',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 32),
                                              const Divider(),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 50,
                                                child: ElevatedButton.icon(
                                                  onPressed: _loadingAction
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            _showQrOverlay =
                                                                false;
                                                          });
                                                          _scanStudentQr(
                                                            tripId: tripId,
                                                          );
                                                        },
                                                  icon: const Icon(
                                                    Icons.qr_code_scanner,
                                                    size: 24,
                                                  ),
                                                  label: const Text(
                                                    'Scan Student QR',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Student list overlay (expandable from bottom)
                      if (_showStudentList && tripId != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          top: MediaQuery.of(context).size.height * 0.25,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showStudentList = false;
                              });
                            },
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: GestureDetector(
                                onTap: () {},
                                child: Container(
                                  margin: const EdgeInsets.only(top: 60),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Boarding Status',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () {
                                                setState(() {
                                                  _showStudentList = false;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: studentById.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No students assigned',
                                                ),
                                              )
                                            : ListView.separated(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                itemCount:
                                                    orderedStudentIds.length,
                                                separatorBuilder:
                                                    (context, index) =>
                                                        const Divider(
                                                          height: 20,
                                                        ),
                                                itemBuilder: (context, i) {
                                                  final studentId =
                                                      orderedStudentIds[i].key;
                                                  final student =
                                                      studentById[studentId];
                                                  final studentName =
                                                      (student?['student_name'] ??
                                                              studentId)
                                                          .toString();
                                                  final parentPhone =
                                                      (student?['parent_phone'] ??
                                                              '')
                                                          .toString();

                                                  final isAbsentToday =
                                                      (student?['attendance_override'] ??
                                                                  '')
                                                              .toString() ==
                                                          'absent' &&
                                                      (student?['attendance_date_ymd'] ??
                                                                  '')
                                                              .toString() ==
                                                          _todayYmd();

                                                  final p = passengers
                                                      .firstWhere(
                                                        (x) =>
                                                            (x['student_id'] ??
                                                                    '')
                                                                .toString() ==
                                                            studentId,
                                                        orElse: () =>
                                                            const <
                                                              String,
                                                              dynamic
                                                            >{},
                                                      );
                                                  final statusStr =
                                                      (p['status'] ??
                                                              'not_boarded')
                                                          .toString();
                                                  final statusEnum =
                                                      BoardingStatusCodec.fromJson(
                                                        statusStr,
                                                      );

                                                  final uiStatusEnum =
                                                      isAbsentToday
                                                      ? BoardingStatus.absent
                                                      : statusEnum;

                                                  final arrivedLabel =
                                                      isAfternoon
                                                      ? 'Arrived (Home)'
                                                      : 'Arrived (School)';

                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: isAbsentToday
                                                          ? Colors.orange
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                )
                                                          : Colors.grey[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: ListTile(
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 8,
                                                          ),
                                                      leading: Container(
                                                        width: 48,
                                                        height: 48,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              uiStatusEnum ==
                                                                  BoardingStatus
                                                                      .boarded
                                                              ? Colors.green
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    )
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .alighted
                                                              ? Colors.blue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    )
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .absent
                                                              ? Colors.orange
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    )
                                                              : Colors.grey
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          uiStatusEnum ==
                                                                  BoardingStatus
                                                                      .boarded
                                                              ? Icons
                                                                    .check_circle
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .alighted
                                                              ? Icons.flag
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .absent
                                                              ? Icons
                                                                    .remove_circle
                                                              : Icons
                                                                    .radio_button_unchecked,
                                                          color:
                                                              uiStatusEnum ==
                                                                  BoardingStatus
                                                                      .boarded
                                                              ? Colors.green
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .alighted
                                                              ? Colors.blue
                                                              : uiStatusEnum ==
                                                                    BoardingStatus
                                                                        .absent
                                                              ? Colors.orange
                                                              : Colors.grey,
                                                          size: 28,
                                                        ),
                                                      ),
                                                      title: Text(
                                                        studentName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      subtitle: Text(
                                                        isAbsentToday
                                                            ? 'Status: $statusStr • ABSENT TODAY'
                                                            : 'Status: $statusStr',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      trailing: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (parentPhone
                                                              .isNotEmpty)
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.phone,
                                                              ),
                                                              color:
                                                                  Colors.green,
                                                              onPressed: () =>
                                                                  _launchCall(
                                                                    parentPhone,
                                                                  ),
                                                            ),
                                                          PopupMenuButton<
                                                            String
                                                          >(
                                                            onSelected: (v) async {
                                                              final next =
                                                                  BoardingStatusCodec.fromJson(
                                                                    v,
                                                                  );
                                                              await _tripService
                                                                  .updatePassengerStatus(
                                                                    tripId,
                                                                    studentId,
                                                                    next,
                                                                  );

                                                              try {
                                                                final studentSnap = await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'drivers',
                                                                    )
                                                                    .doc(
                                                                      widget
                                                                          .driverId,
                                                                    )
                                                                    .collection(
                                                                      'students',
                                                                    )
                                                                    .doc(
                                                                      studentId,
                                                                    )
                                                                    .get();
                                                                final parentId =
                                                                    (studentSnap.data()?['parent_id'] ??
                                                                            '')
                                                                        .toString();
                                                                final studentName =
                                                                    (studentSnap.data()?['student_name'] ??
                                                                            studentId)
                                                                        .toString();
                                                                if (parentId
                                                                    .isNotEmpty) {
                                                                  final label = switch (next) {
                                                                    BoardingStatus
                                                                        .notBoarded =>
                                                                      'Not Boarded',
                                                                    BoardingStatus
                                                                        .boarded =>
                                                                      'Boarded',
                                                                    BoardingStatus
                                                                        .alighted =>
                                                                      'Arrived',
                                                                    BoardingStatus
                                                                        .absent =>
                                                                      'Absent',
                                                                  };
                                                                  await _notifications.createUnique(
                                                                    notificationId:
                                                                        'boarding_${tripId}_${studentId}_${BoardingStatusCodec.toJson(next)}',
                                                                    userId:
                                                                        parentId,
                                                                    type:
                                                                        'boarding',
                                                                    message:
                                                                        '$studentName: $label',
                                                                  );
                                                                }
                                                              } catch (_) {}
                                                            },
                                                            icon: const Icon(
                                                              Icons.more_vert,
                                                            ),
                                                            itemBuilder: (_) => [
                                                              const PopupMenuItem(
                                                                value:
                                                                    'not_boarded',
                                                                child: Text(
                                                                  'Not Boarded',
                                                                ),
                                                              ),
                                                              const PopupMenuItem(
                                                                value:
                                                                    'boarded',
                                                                child: Text(
                                                                  'Boarded',
                                                                ),
                                                              ),
                                                              PopupMenuItem(
                                                                value:
                                                                    'alighted',
                                                                child: Text(
                                                                  arrivedLabel,
                                                                ),
                                                              ),
                                                              const PopupMenuItem(
                                                                value: 'absent',
                                                                child: Text(
                                                                  'Absent',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

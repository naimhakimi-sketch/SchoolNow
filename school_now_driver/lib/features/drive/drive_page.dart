import 'dart:async';
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

  // Live location tracking
  LatLng? _currentLocation;
  StreamSubscription<LocationData>? _locationSubscription;

  // Cached operator location
  LatLng? _operatorLocation;

  // Cache for school locations and types
  final Map<String, LatLng> _schoolLocations = {};
  final Map<String, String> _schoolTypes = {};
  final Map<String, String> _schoolNames = {};

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
      // Use the already-tracked live location if available
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 16);
        return;
      }

      // Fallback: request location explicitly
      bool serviceEnabled = await _deviceLocation.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _deviceLocation.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location service is disabled')),
            );
          }
          return;
        }
      }

      PermissionStatus permission = await _deviceLocation.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _deviceLocation.requestPermission();
        if (permission != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      final loc = await _deviceLocation.getLocation();
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get location')),
          );
        }
        return;
      }

      if (!mounted) return;
      _mapController.move(LatLng(lat.toDouble(), lng.toDouble()), 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> _centerAndZoom() async {
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

      // Zoom closer than normal center
      _mapController.move(LatLng(lat, lng), 18);
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

      var studentIds = await _studentService.getApprovedStudentIds(
        widget.driverId,
      );

      // Filter students by trip type (going/return/both) based on route type
      // Morning routes (going) use students with trip_type 'going' or 'both'
      // Afternoon routes (return) use students with trip_type 'return' or 'both'
      final isGoingRoute = _selectedRouteType == 'morning';
      final isReturnRoute =
          _selectedRouteType == 'primary_pm' ||
          _selectedRouteType == 'secondary_pm';

      final tripTypeFiltered = <String>[];
      final studentsCollection = FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .collection('students');

      for (final studentId in studentIds) {
        try {
          final studentSnap = await studentsCollection.doc(studentId).get();
          if (!studentSnap.exists) continue;
          final tripType = (studentSnap.data()?['trip_type'] ?? 'both')
              .toString();

          // Include student if their trip_type matches the route type
          bool shouldInclude = false;
          if (tripType == 'both') {
            shouldInclude = true;
          } else if (isGoingRoute && tripType == 'going') {
            shouldInclude = true;
          } else if (isReturnRoute && tripType == 'return') {
            shouldInclude = true;
          }

          if (shouldInclude) {
            tripTypeFiltered.add(studentId);
          }
        } catch (_) {
          // Skip on error, default to not including this student
        }
      }

      studentIds = tripTypeFiltered;

      // For afternoon routes, filter students by school type.
      if (_selectedRouteType == 'primary_pm' ||
          _selectedRouteType == 'secondary_pm') {
        final targetSchoolType = _selectedRouteType == 'primary_pm'
            ? 'primary'
            : 'secondary';
        final filtered = <String>[];
        for (final studentId in studentIds) {
          try {
            final docs = await FirebaseFirestore.instance
                .collectionGroup('children')
                .where(FieldPath.documentId, isEqualTo: studentId)
                .limit(1)
                .get();
            if (docs.docs.isEmpty) continue;
            final studentData = docs.docs.first.data();
            final schoolId = (studentData['school_id'] ?? '').toString();
            if (schoolId.isEmpty) continue;
            final schoolDoc = await FirebaseFirestore.instance
                .collection('schools')
                .doc(schoolId)
                .get();
            final schoolType = (schoolDoc.data()?['type'] ?? 'primary')
                .toString()
                .toLowerCase();
            if (schoolType == targetSchoolType) {
              filtered.add(studentId);
            }
          } catch (_) {
            // Skip on error
          }
        }
        studentIds = filtered;
      }

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

            // First check whether this student exists in this driver's
            // assigned students collection. If not, inform the driver and
            // do not mark boarded. Also ensure the student is listed on the
            // trip's passenger list.
            try {
              final studentSnap = await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(widget.driverId)
                  .collection('students')
                  .doc(studentId)
                  .get();
              if (!studentSnap.exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This student is not assigned to your service — they are not using your route.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              // Also confirm the trip's passenger list includes this student.
              final tripSnap = await FirebaseFirestore.instance
                  .collection('trips')
                  .doc(tripId)
                  .get();
              final trip = tripSnap.data();
              final passengers =
                  (trip?['passengers'] as List?)?.cast<Map>() ?? <Map>[];
              final inTrip = passengers.any(
                (p) => (p['student_id'] ?? '').toString() == studentId,
              );
              if (!inTrip) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "This student isn't assigned to this trip — they're not using your service.",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
            } catch (_) {
              // If lookup fails for any reason, fall back to attempting the update.
            }

            await _tripService.upsertPassengerStatus(
              tripId,
              studentId,
              BoardingStatus.boarded,
            );

            String studentName = studentId;
            try {
              final studentSnap = await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(widget.driverId)
                  .collection('students')
                  .doc(studentId)
                  .get();
              final parentId = (studentSnap.data()?['parent_id'] ?? '')
                  .toString();
              studentName = _displayStudentName(studentSnap.data(), studentId);
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
                SnackBar(content: Text('Marked boarded: $studentName')),
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
    final lat =
        (m['lat'] as num?)?.toDouble() ?? (m['latitude'] as num?)?.toDouble();
    final lng =
        (m['lng'] as num?)?.toDouble() ?? (m['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _displayStudentName(Map<String, dynamic>? student, String studentId) {
    if (student == null) return studentId;
    return ((student['student_name'] ??
            student['name'] ??
            student['child_name'] ??
            studentId))
        .toString();
  }

  LatLng? _driverHome(Map<String, dynamic>? driverData) {
    final home = (driverData?['home_location'] as Map?)
        ?.cast<String, dynamic>();
    return _latLngFromMap(home);
  }

  LatLng? _schoolPoint(Map<String, dynamic>? driverData) {
    final school = (driverData?['school_location'] as Map?)
        ?.cast<String, dynamic>();
    return _latLngFromMap(school);
  }

  Future<LatLng?> _getOperatorLocation() async {
    if (_operatorLocation != null) return _operatorLocation;

    try {
      final operatorDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('operator')
          .get();

      if (operatorDoc.exists) {
        final data = operatorDoc.data();
        final lat = data?['latitude'] as double?;
        final lng = data?['longitude'] as double?;
        if (lat != null && lng != null) {
          _operatorLocation = LatLng(lat, lng);
          return _operatorLocation;
        }
      }
    } catch (e) {
      debugPrint('Error loading operator location: $e');
    }
    return null;
  }

  LatLng? _getCachedOperatorLocation() {
    return _operatorLocation;
  }

  LatLng? _getSchoolLocation(String schoolId) {
    return _schoolLocations[schoolId];
  }

  Future<void> _loadSchoolLocations(
    Map<String, Map<String, dynamic>> studentById,
  ) async {
    final schoolIds = studentById.values
        .map((student) => (student['school_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final schoolId in schoolIds) {
      if (_schoolLocations.containsKey(schoolId)) continue;

      try {
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();

        if (schoolDoc.exists) {
          final data = schoolDoc.data();
          final geoLocation = data?['geo_location'] as Map?;
          final schoolType = (data?['type'] ?? 'primary')
              .toString()
              .toLowerCase();
          final schoolName = (data?['name'] ?? '').toString();

          if (geoLocation != null) {
            final lat = (geoLocation['lat'] as num?)?.toDouble();
            final lng = (geoLocation['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _schoolLocations[schoolId] = LatLng(lat, lng);
              _schoolTypes[schoolId] = schoolType;
              _schoolNames[schoolId] = schoolName;
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading school location for $schoolId: $e');
      }
    }
  }

  /// Eagerly fetch school types for filtering (blocking).
  Future<void> _ensureSchoolTypesLoaded(
    Map<String, Map<String, dynamic>> studentById,
  ) async {
    final schoolIds = studentById.values
        .map((student) => (student['school_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final missingSchoolIds = schoolIds
        .where((id) => !_schoolTypes.containsKey(id))
        .toList();

    if (missingSchoolIds.isEmpty) return;

    // Fetch all missing school types
    final batch = await FirebaseFirestore.instance
        .collection('schools')
        .where(FieldPath.documentId, whereIn: missingSchoolIds)
        .get();

    for (final doc in batch.docs) {
      final schoolType = (doc.data()['type'] ?? 'primary')
          .toString()
          .toLowerCase();
      _schoolTypes[doc.id] = schoolType;
    }
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
    debugPrint(
      'Drive._buildRoutePolyline: routeType=$routeType passengers=${passengers.length} studentDocs=${studentById.length} driverKeys=${driverData?.keys.toList()}',
    );

    // Prefer explicit currentPosition (route start), then live GPS, then home,
    // then first available pickup point as a graceful fallback.
    LatLng? fallbackFirstStop;
    for (final studentId in studentById.keys) {
      final studentData = studentById[studentId]!;
      final loc = (studentData['pickup_location'] as Map?)
          ?.cast<String, dynamic>();
      final p = _latLngFromMap(loc);
      if (p != null) {
        fallbackFirstStop = p;
        break;
      }
    }

    final start =
        currentPosition ?? _currentLocation ?? home ?? fallbackFirstStop;
    debugPrint(
      'Drive._buildRoutePolyline: fallbackFirstStop=$fallbackFirstStop start=$start currentPosition=$currentPosition _currentLocation=$_currentLocation home=$home',
    );
    if (start == null) return const [];
    final LatLng startNonNull = start;

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

    final schoolsWithActiveStudents = <String, List<String>>{};
    for (final studentId in studentById.keys) {
      final studentData = studentById[studentId]!;
      final schoolId = (studentData['school_id'] ?? '').toString();
      if (schoolId.isEmpty) continue;

      final status = statusOf(studentId);
      final isActive =
          status != BoardingStatus.absent && status != BoardingStatus.alighted;

      if (isActive) {
        schoolsWithActiveStudents
            .putIfAbsent(schoolId, () => [])
            .add(studentId);
      }
    }

    final isAfternoon = _isAfternoonRoute(routeType);

    if (!isAfternoon) {
      // Morning route: home -> student pickups -> schools (in optimal order)
      final pendingPickups = <Map<String, dynamic>>[];
      final schoolStops = <Map<String, dynamic>>[];

      for (final studentId in studentById.keys) {
        final status = statusOf(studentId);
        if (status == BoardingStatus.boarded ||
            status == BoardingStatus.absent ||
            status == BoardingStatus.alighted) {
          continue;
        }
        final pickup = pickupOf(studentId);
        if (pickup != null) {
          pendingPickups.add({'student_id': studentId, 'point': pickup});
        }
      }
      debugPrint(
        'Drive._buildRoutePolyline: pendingPickups=${pendingPickups.length} ids=${pendingPickups.map((e) => e['student_id']).toList()}',
      );

      // Add schools that have active students
      for (final schoolId in schoolsWithActiveStudents.keys) {
        final schoolLocation = _getSchoolLocation(schoolId);
        if (schoolLocation != null) {
          schoolStops.add({'school_id': schoolId, 'point': schoolLocation});
        }
      }

      final orderedPickups = pendingPickups.isEmpty
          ? const <Map<String, dynamic>>[]
          : _sortStopsByNearestNeighbor(
              origin: startNonNull,
              stops: pendingPickups,
            );
      debugPrint(
        'Drive._buildRoutePolyline: orderedPickups=${orderedPickups.length}',
      );

      final orderedSchools = schoolStops.isEmpty
          ? const <Map<String, dynamic>>[]
          : _sortStopsByNearestNeighbor(
              origin: orderedPickups.isNotEmpty
                  ? orderedPickups.last['point'] as LatLng
                  : startNonNull,
              stops: schoolStops,
            );

      return [
        startNonNull,
        ...orderedPickups.map((e) => e['point'] as LatLng),
        ...orderedSchools.map((e) => e['point'] as LatLng),
      ];
    } else {
      // Afternoon route: current position -> schools (if needed) -> student dropoffs -> home
      final schoolStops = <Map<String, dynamic>>[];
      final remainingDropoffs = <Map<String, dynamic>>[];

      // For school sessions, only visit schools of the matching type first
      final targetSchoolType = routeType == 'primary_pm'
          ? 'primary'
          : routeType == 'secondary_pm'
          ? 'secondary'
          : null;

      // Check if any students still need to be picked up from school (notBoarded)
      bool hasStudentsAtSchool = false;
      for (final schoolId in schoolsWithActiveStudents.keys) {
        final studentIds = schoolsWithActiveStudents[schoolId] ?? [];
        for (final studentId in studentIds) {
          final status = statusOf(studentId);
          if (status == BoardingStatus.notBoarded) {
            hasStudentsAtSchool = true;
            break;
          }
        }
        if (hasStudentsAtSchool) break;
      }

      // Only add schools to route if there are students still waiting to be picked up
      if (hasStudentsAtSchool) {
        // Add schools that have active students (filtered by type for school sessions)
        for (final schoolId in schoolsWithActiveStudents.keys) {
          final schoolLocation = _getSchoolLocation(schoolId);
          final schoolType = _schoolTypes[schoolId] ?? 'primary';

          if (schoolLocation != null &&
              (targetSchoolType == null ||
                  schoolType.toLowerCase() == targetSchoolType)) {
            schoolStops.add({'school_id': schoolId, 'point': schoolLocation});
          }
        }
      }

      // Add remaining dropoffs (only from schools we visited for primary sessions)
      final visitedSchoolIds = targetSchoolType != null
          ? schoolsWithActiveStudents.keys
                .where(
                  (schoolId) =>
                      (_schoolTypes[schoolId] ?? 'primary').toLowerCase() ==
                      targetSchoolType,
                )
                .toSet()
          : schoolsWithActiveStudents.keys.toSet();

      for (final studentId in studentById.keys) {
        final studentData = studentById[studentId]!;
        final studentSchoolId = (studentData['school_id'] ?? '').toString();

        // For primary sessions, only drop off students from primary schools we visited
        if (targetSchoolType != null &&
            !visitedSchoolIds.contains(studentSchoolId)) {
          continue;
        }

        final status = statusOf(studentId);
        if (status == BoardingStatus.absent ||
            status == BoardingStatus.alighted) {
          continue;
        }
        // For afternoon routes, drop off at home (pickup_location)
        final dropoff = pickupOf(studentId);
        if (dropoff != null) {
          remainingDropoffs.add({'student_id': studentId, 'point': dropoff});
        }
      }
      debugPrint(
        'Drive._buildRoutePolyline: remainingDropoffs=${remainingDropoffs.length}',
      );

      final orderedSchools = schoolStops.isEmpty
          ? const <Map<String, dynamic>>[]
          : _sortStopsByNearestNeighbor(
              origin: startNonNull,
              stops: schoolStops,
            );

      final orderedDropoffs = remainingDropoffs.isEmpty
          ? const <Map<String, dynamic>>[]
          : _sortStopsByNearestNeighbor(
              origin: orderedSchools.isNotEmpty
                  ? orderedSchools.last['point'] as LatLng
                  : startNonNull,
              stops: remainingDropoffs,
            );
      debugPrint(
        'Drive._buildRoutePolyline: orderedDropoffs=${orderedDropoffs.length}',
      );

      return [
        startNonNull,
        ...orderedSchools.map((e) => e['point'] as LatLng),
        ...orderedDropoffs.map((e) => e['point'] as LatLng),
        (_getCachedOperatorLocation() ?? home) ?? startNonNull,
      ];
    }
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

    // Use the passed currentPosition, then live GPS, then home, then school.
    final start = currentPosition ?? _currentLocation ?? home ?? school;
    if (start == null) return null;
    final LatLng startNonNull = start;

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
          origin: startNonNull,
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
        origin: school ?? startNonNull,
        stops: pendingDropoffs,
      );
      return ordered.first['point'] as LatLng;
    }

    return home;
  }

  Widget _buildFullScreenMap({
    required String? tripId,
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

    // Add markers for cached schools (destinations)
    for (final entry in _schoolLocations.entries) {
      final sid = entry.key;
      final point = entry.value;
      final type = _schoolTypes[sid] ?? 'primary';
      final name = _schoolNames[sid] ?? '';

      Color color;
      switch (type) {
        case 'secondary':
          color = Colors.green;
          break;
        case 'primary':
        default:
          color = Colors.blue;
      }

      markers.add(
        Marker(
          point: point,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () async {
              _mapController.move(point, 16);
              // Only show arrive action when on an active trip and morning route
              if (tripId == null) return;
              final isMorning = routeType == 'morning';
              if (!isMorning) return;

              // Compute student ids for this school that are part of the trip
              final passengerIds = passengers
                  .map((e) => (e['student_id'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toSet();
              final ids = studentById.entries
                  .where((e) => (e.value['school_id'] ?? '').toString() == sid)
                  .map((e) => e.key)
                  .where((id) => passengerIds.contains(id))
                  .toList();
              if (ids.isEmpty) return;

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    name.isNotEmpty ? 'Arrive at $name' : 'Arrive at school',
                  ),
                  content: Text(
                    'Mark ${ids.length} student(s) from this school as Arrived (School)?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Arrive'),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              setState(() {
                _loadingAction = true;
                _error = null;
              });
              try {
                await _tripService.markStudentsArrivedAtSchool(tripId, ids);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Marked ${ids.length} student(s) arrived at ${name.isNotEmpty ? name : 'school'}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _error = 'Failed to mark arrived: $e';
                });
              } finally {
                if (mounted) {
                  setState(() {
                    _loadingAction = false;
                    // clear cached route so it's recomputed from updated trip state
                    _routedPolyline = null;
                    _routedKey = null;
                  });
                }
              }
            },
            child: Tooltip(
              message: name.isNotEmpty ? name : 'School',
              child: Icon(Icons.school, color: color, size: 36),
            ),
          ),
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

    // Add operator location marker
    final operatorLocation = _getCachedOperatorLocation();
    if (operatorLocation != null) {
      markers.add(
        Marker(
          point: operatorLocation,
          width: 44,
          height: 44,
          child: const Icon(Icons.business, color: Colors.purple, size: 40),
        ),
      );
    }

    // Add current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: 0.2),
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
          ),
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
        // Move center/zoom buttons to top-right so they're visible above overlays
        Positioned(
          right: 10,
          top: 100,
          child: FloatingActionButton.small(
            heroTag: 'drive_center',
            onPressed: _centerOnMyLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          right: 10,
          top: 160,
          child: FloatingActionButton.small(
            heroTag: 'drive_zoom',
            onPressed: _centerAndZoom,
            child: const Icon(Icons.zoom_in),
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
  void initState() {
    super.initState();
    _startLocationTracking();
    _loadOperatorLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() async {
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

      _locationSubscription = _deviceLocation.onLocationChanged.listen((
        LocationData locationData,
      ) {
        if (locationData.latitude != null && locationData.longitude != null) {
          final newLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          if (mounted) {
            setState(() {
              _currentLocation = newLocation;
              // Also update route start if not already set
              _currentRouteStart ??= newLocation;
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  void _loadOperatorLocation() async {
    await _getOperatorLocation();
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

            // Load school locations asynchronously (for map markers)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadSchoolLocations(studentById);
            });

            // Wrap in FutureBuilder to ensure school types are loaded before filtering
            return FutureBuilder<void>(
              future: _ensureSchoolTypesLoaded(studentById),
              builder: (context, _) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                  stream: _tripService.streamActiveTripForDriver(
                    widget.driverId,
                  ),
                  builder: (context, tripSnap) {
                    final tripDoc = tripSnap.data;
                    final trip = tripDoc?.data();

                    final tripId = tripDoc?.id;
                    final passengers =
                        (trip?['passengers'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const [];
                    final routeType =
                        (trip?['route_type'] ?? _selectedRouteType).toString();
                    final studentIds = studentById.keys;

                    final isAfternoon = _isAfternoonRoute(routeType);

                    // Filter students by trip type based on route type
                    final isGoingRoute = routeType == 'morning';
                    final isReturnRoute =
                        routeType == 'primary_pm' ||
                        routeType == 'secondary_pm';

                    // First filter by trip type
                    final tripTypeFiltered = <String, Map<String, dynamic>>{};
                    for (final entry in studentById.entries) {
                      final tripType = (entry.value['trip_type'] ?? 'both')
                          .toString();

                      bool shouldInclude = false;
                      if (tripType == 'both') {
                        shouldInclude = true;
                      } else if (isGoingRoute && tripType == 'going') {
                        shouldInclude = true;
                      } else if (isReturnRoute && tripType == 'return') {
                        shouldInclude = true;
                      }

                      if (shouldInclude) {
                        tripTypeFiltered[entry.key] = entry.value;
                      }
                    }

                    // For PM sessions, then filter students by school type
                    final targetSchoolType = routeType == 'primary_pm'
                        ? 'primary'
                        : routeType == 'secondary_pm'
                        ? 'secondary'
                        : null;

                    final filteredStudentById = targetSchoolType != null
                        ? {
                            for (final entry in tripTypeFiltered.entries)
                              if ((_schoolTypes[(entry.value['school_id'] ?? '')
                                              .toString()] ??
                                          'primary')
                                      .toLowerCase() ==
                                  targetSchoolType)
                                entry.key: entry.value,
                          }
                        : tripTypeFiltered;

                    final orderedStudentIds =
                        filteredStudentById.entries.toList()..sort((a, b) {
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
                            studentById: filteredStudentById,
                            currentPosition: _currentRouteStart,
                          );
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
                          studentIds: filteredStudentById.keys,
                        );

                    return Scaffold(
                      body: Stack(
                        children: [
                          // Full screen map
                          _buildFullScreenMap(
                            tripId: tripId,
                            driverData: driverData,
                            routeType: tripId == null
                                ? _selectedRouteType
                                : routeType,
                            passengers: passengers,
                            studentById: filteredStudentById,
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
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
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                        child: Text(
                                                          'Primary PM',
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: 'secondary_pm',
                                                        child: Text(
                                                          'Secondary PM',
                                                        ),
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
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : const Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons.play_arrow,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Start Service',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
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
                                                          : () => _endTrip(
                                                              tripId,
                                                            ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
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
                                                                    strokeWidth:
                                                                        2,
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
                                                      backgroundColor:
                                                          Colors.white,
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
                                                          : () =>
                                                                _focusNextStop(
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
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
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
                                                          : Icons
                                                                .keyboard_arrow_up,
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
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(2),
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
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
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
                                                      backgroundColor:
                                                          Colors.white,
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
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
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
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(2),
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
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    itemCount: orderedStudentIds
                                                        .length,
                                                    separatorBuilder:
                                                        (context, index) =>
                                                            const Divider(
                                                              height: 20,
                                                            ),
                                                    itemBuilder: (context, i) {
                                                      final studentId =
                                                          orderedStudentIds[i]
                                                              .key;
                                                      final student =
                                                          studentById[studentId];
                                                      final studentName =
                                                          _displayStudentName(
                                                            student,
                                                            studentId,
                                                          );
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
                                                          ? BoardingStatus
                                                                .absent
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
                                                                      alpha:
                                                                          0.06,
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
                                                                  ? Colors
                                                                        .orange
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        )
                                                                  : Colors.grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                              shape: BoxShape
                                                                  .circle,
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
                                                                  ? Colors
                                                                        .orange
                                                                  : Colors.grey,
                                                              size: 28,
                                                            ),
                                                          ),
                                                          title: Text(
                                                            studentName,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          subtitle: Text(
                                                            isAbsentToday
                                                                ? 'Status: $statusStr • ABSENT TODAY'
                                                                : 'Status: $statusStr',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          trailing: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              if (parentPhone
                                                                  .isNotEmpty)
                                                                IconButton(
                                                                  icon: const Icon(
                                                                    Icons.phone,
                                                                  ),
                                                                  color: Colors
                                                                      .green,
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
                                                                    final studentName = _displayStudentName(
                                                                      studentSnap
                                                                          .data(),
                                                                      studentId,
                                                                    );
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
                                                                  Icons
                                                                      .more_vert,
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
                                                                    value:
                                                                        'absent',
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
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import '../../models/boarding_status.dart';
import '../../services/live_location_service.dart';
import '../../services/notification_service.dart';
import '../../services/osrm_routing_service.dart';
import '../../services/parent_service.dart';

class MonitorPage extends StatefulWidget {
  final String parentId;
  final QueryDocumentSnapshot<Map<String, dynamic>> childDoc;

  const MonitorPage({
    super.key,
    required this.parentId,
    required this.childDoc,
  });

  @override
  State<MonitorPage> createState() => _MonitorPageState();

  static LatLng? _latLngFromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final lat =
        (m['lat'] as num?)?.toDouble() ?? (m['latitude'] as num?)?.toDouble();
    final lng =
        (m['lng'] as num?)?.toDouble() ?? (m['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static String _statusLabel(BoardingStatus s) {
    return switch (s) {
      BoardingStatus.notBoarded => 'Not Boarded',
      BoardingStatus.boarded => 'Boarded',
      BoardingStatus.alighted => 'Arrived',
      BoardingStatus.absent => 'Absent',
    };
  }

  static LatLng? _pickupFromParent(Map<String, dynamic>? parent) {
    if (parent == null) return null;
    final lat = (parent['pickup_lat'] as num?)?.toDouble();
    final lng = (parent['pickup_lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return MonitorPage._latLngFromMap(
      (parent['pickup_location'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class _MonitorPageState extends State<MonitorPage> {
  final _parentService = ParentService();
  final _notificationService = NotificationService();
  final _live = TripLiveLocationService();
  final _mapController = MapController();
  final _routingService = OsrmRoutingService();

  final Map<String, LatLng> _schoolLocations = {};
  final Map<String, String> _schoolTypes = {};
  final Map<String, String> _schoolNames = {};

  String? _routedKey;
  List<LatLng>? _routedPolyline;
  bool _routingInFlight = false;

  bool _autoCenteredOnDriver = false;

  String? _proximityNotifiedTripId;

  String _pointKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  List<Marker> _buildRouteStopMarkers(
    List<LatLng> stopPoints,
    Set<String> seenKeys,
  ) {
    final markers = <Marker>[];
    for (var i = 1; i < stopPoints.length; i++) {
      final point = stopPoints[i];
      final key = _pointKey(point);
      if (!seenKeys.add(key)) continue;
      markers.add(
        Marker(
          point: point,
          width: 32,
          height: 32,
          child: const Icon(Icons.location_on, color: Colors.red, size: 28),
        ),
      );
    }
    return markers;
  }

  List<Marker> _buildSchoolMarkers({
    required String? tripId,
    required String routeType,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
    required Set<String> seenKeys,
  }) {
    final markers = <Marker>[];
    final isMorning = routeType == 'morning';

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

      // Check if there are any students from this school that are not yet arrived
      final passengerIds = passengers
          .map((e) => (e['student_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      final schoolStudentIds = studentById.entries
          .where((e) => (e.value['school_id'] ?? '').toString() == sid)
          .map((e) => e.key)
          .where((id) => passengerIds.contains(id))
          .toList();

      // Filter to only those not yet arrived
      final remainingStudents = schoolStudentIds.where((id) {
        final p = passengers.firstWhere(
          (x) => (x['student_id'] ?? '').toString() == id,
          orElse: () => const <String, dynamic>{},
        );
        final status = BoardingStatusCodec.fromJson(
          (p['status'] ?? 'not_boarded').toString(),
        );
        // Show school if students are not arrived and not absent
        return status != BoardingStatus.alighted &&
            status != BoardingStatus.absent;
      }).toList();

      // Skip this school if no remaining students
      if (remainingStudents.isEmpty) continue;

      final key = _pointKey(point);
      if (!seenKeys.add(key)) continue;

      markers.add(
        Marker(
          point: point,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () async {
              _mapController.move(point, 16);
              if (tripId == null || !isMorning) return;

              // Use the already-filtered remainingStudents list
              if (remainingStudents.isEmpty) return;

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    name.isNotEmpty ? 'Arrive at $name' : 'Arrive at school',
                  ),
                  content: Text(
                    'Mark ${remainingStudents.length} student(s) from this school as Arrived (School)?',
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
                _routingInFlight = true;
              });
              try {
                final tripDoc = await FirebaseFirestore.instance
                    .collection('trips')
                    .doc(tripId)
                    .get();
                final data = tripDoc.data() ?? <String, dynamic>{};
                final currentPassengers =
                    (data['passengers'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];

                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final updatedPassengers = currentPassengers.map((p) {
                  final studentId = (p['student_id'] ?? '').toString();
                  if (!remainingStudents.contains(studentId)) return p;
                  final status = BoardingStatusCodec.fromJson(
                    (p['status'] ?? 'not_boarded').toString(),
                  );
                  if (status == BoardingStatus.absent) return p;
                  return {
                    ...p,
                    'status': BoardingStatusCodec.toJson(
                      BoardingStatus.alighted,
                    ),
                    'updated_at': nowMs,
                  };
                }).toList();

                await FirebaseFirestore.instance
                    .collection('trips')
                    .doc(tripId)
                    .update({'passengers': updatedPassengers});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Marked ${remainingStudents.length} student(s) arrived at ${name.isNotEmpty ? name : 'school'}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint(
                  'Monitor: error marking students arrived at school: $e',
                );
              } finally {
                if (mounted) {
                  setState(() {
                    _routingInFlight = false;
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

    return markers;
  }

  Widget _buildOverlayPanels({
    required bool attending,
    required ValueChanged<bool> onAttendanceChanged,
    required String statusText,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Attending today'),
                subtitle: const Text('Set to Absent if not riding today'),
                value: attending,
                onChanged: onAttendanceChanged,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(statusText)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // SRS FR-PA-5.6: reset to Attending daily unless parent sets otherwise.
    _parentService.ensureAttendanceDefaultForToday(
      parentId: widget.parentId,
      childId: widget.childDoc.id,
    );
  }

  Future<void> _centerOnParentHome() async {
    try {
      final parentDoc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(widget.parentId)
          .get();

      if (parentDoc.exists) {
        final data = parentDoc.data();
        if (data != null &&
            data['pickup_lat'] != null &&
            data['pickup_lng'] != null) {
          final lat = data['pickup_lat'];
          final lng = data['pickup_lng'];
          _mapController.move(LatLng(lat, lng), 16);
        }
      }
    } catch (_) {}
  }

  void _centerOnDriver(LatLng? driverPoint) {
    if (driverPoint == null) return;
    _mapController.move(driverPoint, 16);
  }

  void _maybeAutoCenterOnDriver(LatLng? driverPoint) {
    if (driverPoint == null) return;
    if (_autoCenteredOnDriver) return;
    _autoCenteredOnDriver = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(driverPoint, 16);
    });
  }

  bool _isAfternoonRoute(String routeType) =>
      routeType == 'primary_pm' || routeType == 'secondary_pm';

  LatLng _roundLatLng(LatLng p, {int decimals = 4}) {
    final lat = double.parse(p.latitude.toStringAsFixed(decimals));
    final lng = double.parse(p.longitude.toStringAsFixed(decimals));
    return LatLng(lat, lng);
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
    debugPrint(
      'Monitor._ensureRoutedPolyline: routeType=$routeType stops=${stops.length} key=$key',
    );
    if (_routedKey == key) return;
    if (_routingInFlight) return;

    setState(() {
      _routingInFlight = true;
    });

    _routingService
        .routeDrivingWithSteps(stops, includeSteps: false)
        .then((route) {
          if (!mounted) return;
          final routed = route?.geometry ?? const <LatLng>[];
          final ok = routed.length >= 2;
          if (ok) {
            final first = routed.first;
            final last = routed.last;
            debugPrint(
              'Monitor._ensureRoutedPolyline: got route geometry length=${routed.length} ok=$ok first=${first.latitude.toStringAsFixed(6)},${first.longitude.toStringAsFixed(6)} last=${last.latitude.toStringAsFixed(6)},${last.longitude.toStringAsFixed(6)} for key=$key',
            );
          } else {
            debugPrint(
              'Monitor._ensureRoutedPolyline: got route geometry length=${routed.length} ok=$ok for key=$key',
            );
          }
          setState(() {
            _routedKey = key;
            _routedPolyline = ok ? routed : null;
          });
        })
        .catchError((e) {
          debugPrint(
            'Monitor._ensureRoutedPolyline: routing error for key=$key error=$e',
          );
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

  LatLng? _driverHome(Map<String, dynamic>? driverData) {
    final home = (driverData?['home_location'] as Map?)
        ?.cast<String, dynamic>();
    return MonitorPage._latLngFromMap(home);
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

  Future<void> _ensureSchoolLocations(
    Map<String, Map<String, dynamic>> studentById,
  ) async {
    final schoolIds = studentById.values
        .map((s) => (s['school_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final missing = schoolIds
        .where((id) => !_schoolTypes.containsKey(id))
        .toList();
    if (missing.isEmpty) return;

    for (final schoolId in missing) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
        if (!doc.exists) continue;
        final data = doc.data();
        final geo = data?['geo_location'] as Map?;
        final schoolType = (data?['type'] ?? 'primary')
            .toString()
            .toLowerCase();
        final schoolName = (data?['name'] ?? '').toString();
        if (geo != null) {
          final lat = (geo['lat'] as num?)?.toDouble();
          final lng = (geo['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            setState(() {
              _schoolLocations[schoolId] = LatLng(lat, lng);
              _schoolTypes[schoolId] = schoolType;
              _schoolNames[schoolId] = schoolName;
            });
          }
        }
      } catch (e) {
        debugPrint('Monitor: error loading school $schoolId: $e');
      }
    }
  }

  LatLng? _getSchoolLocation(String schoolId) {
    return _schoolLocations[schoolId];
  }

  /// Eagerly fetch school types for filtering (blocking) to mirror the driver logic.
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

    try {
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
    } catch (e) {
      debugPrint('Monitor: error loading school types: $e');
    }
  }

  LatLng? _getCachedOperatorLocation() {
    return null;
  }

  List<LatLng> _buildRoutePolylineStops({
    required String routeType,
    required Map<String, dynamic>? driverData,
    required LatLng? driverLivePoint,
    required List<Map<String, dynamic>> passengers,
    required Map<String, Map<String, dynamic>> studentById,
  }) {
    final home = _driverHome(driverData);
    debugPrint(
      'Monitor._buildRoutePolylineStops: routeType=$routeType passengers=${passengers.length} studentDocs=${studentById.length} driverKeys=${driverData?.keys.toList()}',
    );

    // Fallback first pickup
    LatLng? fallbackFirstStop;
    for (final studentId in studentById.keys) {
      final studentData = studentById[studentId]!;
      final loc = (studentData['pickup_location'] as Map?)
          ?.cast<String, dynamic>();
      final p = MonitorPage._latLngFromMap(loc);
      if (p != null) {
        fallbackFirstStop = p;
        break;
      }
    }

    final start = driverLivePoint ?? fallbackFirstStop ?? home;
    debugPrint(
      'Monitor._buildRoutePolylineStops: fallbackFirstStop=$fallbackFirstStop start=$start driverLivePoint=$driverLivePoint home=$home',
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
      return MonitorPage._latLngFromMap(loc);
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
      // Afternoon route: current position -> schools (if needed) -> student dropoffs -> home/operator
      final schoolStops = <Map<String, dynamic>>[];
      final remainingDropoffs = <Map<String, dynamic>>[];

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

      if (hasStudentsAtSchool) {
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

        if (targetSchoolType != null &&
            !visitedSchoolIds.contains(studentSchoolId)) {
          continue;
        }

        final status = statusOf(studentId);
        if (status == BoardingStatus.absent ||
            status == BoardingStatus.alighted) {
          continue;
        }
        final dropoff = pickupOf(studentId);
        if (dropoff != null) {
          remainingDropoffs.add({'student_id': studentId, 'point': dropoff});
        }
      }

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

      return [
        startNonNull,
        ...orderedSchools.map((e) => e['point'] as LatLng),
        ...orderedDropoffs.map((e) => e['point'] as LatLng),
        (_getCachedOperatorLocation() ?? home) ?? startNonNull,
      ];
    }
  }

  Widget _buildMap({
    required LatLng initialCenter,
    required double initialZoom,
    required List<Marker> markers,
    required LatLng? driverPoint,
    required List<LatLng> polylinePoints,
    required String heroTag,
    LatLng? parentLocation,
  }) {
    debugPrint(
      'Monitor._buildMap: polyline=${polylinePoints.length} markers=${markers.length} driverPoint=${driverPoint != null} parentLocation=${parentLocation != null}',
    );
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'school_now',
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
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: () {
              if (parentLocation != null) {
                _mapController.move(parentLocation, 16);
              } else {
                _centerOnParentHome();
              }
            },
            child: const Icon(Icons.home),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 64,
          child: FloatingActionButton.small(
            heroTag: '${heroTag}_driver',
            onPressed: () => _centerOnDriver(driverPoint),
            child: const Icon(Icons.directions_bus),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final childRef = _parentService
        .childrenRef(widget.parentId)
        .doc(widget.childDoc.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _parentService.streamParent(widget.parentId),
      builder: (context, parentSnap) {
        final parent = parentSnap.data?.data() ?? const <String, dynamic>{};
        final parentPickupLocation = MonitorPage._pickupFromParent(parent);
        final notifications =
            (parent['notifications'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final proximityAlertEnabled = notifications['proximity_alert'] == true;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: childRef.snapshots(),
          builder: (context, childSnap) {
            final child = childSnap.data?.data() ?? widget.childDoc.data();
            final assignedDriver = (child['assigned_driver_id'] ?? '')
                .toString();
            if (assignedDriver.isEmpty) {
              return const Center(
                child: Text(
                  'No driver assigned. Go to Drivers to request one.',
                ),
              );
            }

            final override = (child['attendance_override'] ?? 'attending')
                .toString();
            final attending = override != 'absent';

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(assignedDriver)
                  .snapshots(),
              builder: (context, driverSnap) {
                final driver =
                    driverSnap.data?.data() ?? const <String, dynamic>{};
                debugPrint('Monitor: driver doc keys=${driver.keys.toList()}');
                final tripId = (driver['active_trip_id'] ?? '').toString();
                debugPrint('Monitor: driver active_trip_id=$tripId');

                if (tripId.isEmpty) {
                  final LatLng? pickup = MonitorPage._latLngFromMap(
                    (child['pickup_location'] as Map?)?.cast<String, dynamic>(),
                  );
                  debugPrint(
                    'Monitor: child pickup_location present=${pickup != null} assignedDriver=$assignedDriver',
                  );

                  return StreamBuilder<DatabaseEvent>(
                    stream: _live.streamDriverLiveLocation(assignedDriver),
                    builder: (context, driverLocSnap) {
                      LatLng center = pickup ?? const LatLng(0, 0);
                      LatLng? driverPoint;

                      final val = driverLocSnap.data?.snapshot.value;
                      if (val is Map) {
                        final m = val.cast<Object?, Object?>();
                        final lat = (m['lat'] as num?)?.toDouble();
                        final lng = (m['lng'] as num?)?.toDouble();
                        if (lat != null && lng != null) {
                          driverPoint = LatLng(lat, lng);
                          center = driverPoint;
                          _maybeAutoCenterOnDriver(driverPoint);
                        }
                      }

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: _buildMap(
                              initialCenter: center,
                              initialZoom: driverPoint != null ? 15 : 2,
                              heroTag: 'monitor_center_no_trip',
                              driverPoint: driverPoint,
                              polylinePoints: const [],
                              markers: [
                                if (pickup != null)
                                  Marker(
                                    point: pickup,
                                    width: 44,
                                    height: 44,
                                    child: const Icon(
                                      Icons.home,
                                      color: Colors.black87,
                                      size: 34,
                                    ),
                                  ),
                                if (driverPoint != null)
                                  Marker(
                                    point: driverPoint,
                                    width: 44,
                                    height: 44,
                                    child: const Icon(
                                      Icons.directions_bus,
                                      color: Colors.blue,
                                      size: 38,
                                    ),
                                  ),
                              ],
                              parentLocation: parentPickupLocation,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: _buildOverlayPanels(
                              attending: attending,
                              onAttendanceChanged: (v) =>
                                  _parentService.setAttendanceForToday(
                                    parentId: widget.parentId,
                                    childId: widget.childDoc.id,
                                    attending: v,
                                  ),
                              statusText: 'Status: Not started',
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('trips')
                      .doc(tripId)
                      .snapshots(),
                  builder: (context, tripSnap) {
                    final trip = tripSnap.data?.data();
                    if (trip == null) {
                      return const Center(child: Text('Trip not found'));
                    }

                    final routeType = (trip['route_type'] ?? 'morning')
                        .toString();

                    final passengers =
                        (trip['passengers'] as List?)?.cast<Map>() ??
                        const <Map>[];
                    final p = passengers
                        .map((e) => e.cast<String, dynamic>())
                        .firstWhere(
                          (x) =>
                              (x['student_id'] ?? '').toString() ==
                              widget.childDoc.id,
                          orElse: () => const <String, dynamic>{},
                        );
                    final fallbackStatus = BoardingStatusCodec.fromJson(
                      (p['status'] ?? 'not_boarded').toString(),
                    );

                    final statusRef = FirebaseDatabase.instance.ref(
                      'boarding_status/$tripId/${widget.childDoc.id}',
                    );

                    return StreamBuilder<DatabaseEvent>(
                      stream: statusRef.onValue,
                      builder: (context, statusSnap) {
                        BoardingStatus status = fallbackStatus;
                        final raw = statusSnap.data?.snapshot.value;
                        if (raw is Map) {
                          final m = raw.cast<Object?, Object?>();
                          final s = (m['status'] ?? '').toString();
                          if (s.isNotEmpty) {
                            status = BoardingStatusCodec.fromJson(s);
                          }
                        }

                        return StreamBuilder<DatabaseEvent>(
                          stream: _live.streamLiveLocation(tripId),
                          builder: (context, locSnap) {
                            LatLng center = const LatLng(0, 0);
                            LatLng? driverPoint;

                            final val = locSnap.data?.snapshot.value;
                            if (val is Map) {
                              final m = val.cast<Object?, Object?>();
                              final lat = (m['lat'] as num?)?.toDouble();
                              final lng = (m['lng'] as num?)?.toDouble();
                              if (lat != null && lng != null) {
                                driverPoint = LatLng(lat, lng);
                                center = driverPoint;
                                _maybeAutoCenterOnDriver(driverPoint);
                              }
                            }

                            final LatLng? pickup = MonitorPage._latLngFromMap(
                              (child['pickup_location'] as Map?)
                                  ?.cast<String, dynamic>(),
                            );

                            // If no trip-specific location yet, fall back to `live_locations/<driverId>`.
                            if (driverPoint == null) {
                              return StreamBuilder<DatabaseEvent>(
                                stream: _live.streamDriverLiveLocation(
                                  assignedDriver,
                                ),
                                builder: (context, driverLocSnap) {
                                  LatLng fallbackCenter = center;
                                  LatLng? fallbackDriverPoint;

                                  final raw =
                                      driverLocSnap.data?.snapshot.value;
                                  if (raw is Map) {
                                    final m = raw.cast<Object?, Object?>();
                                    final lat = (m['lat'] as num?)?.toDouble();
                                    final lng = (m['lng'] as num?)?.toDouble();
                                    if (lat != null && lng != null) {
                                      fallbackDriverPoint = LatLng(lat, lng);
                                      fallbackCenter = fallbackDriverPoint;
                                      _maybeAutoCenterOnDriver(
                                        fallbackDriverPoint,
                                      );
                                    }
                                  }

                                  if (proximityAlertEnabled &&
                                      pickup != null &&
                                      fallbackDriverPoint != null) {
                                    final meters = const Distance()(
                                      pickup,
                                      fallbackDriverPoint,
                                    );
                                    if (meters <= 200 &&
                                        _proximityNotifiedTripId != tripId) {
                                      _proximityNotifiedTripId = tripId;
                                      final childName =
                                          (child['child_name'] ?? 'Student')
                                              .toString();
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        _notificationService.createUnique(
                                          notificationId:
                                              'proximity_${tripId}_${widget.childDoc.id}',
                                          userId: widget.parentId,
                                          type: 'proximity',
                                          message:
                                              'Driver is near pickup for $childName',
                                        );
                                      });
                                    }
                                  }

                                  return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('drivers')
                                        .doc(assignedDriver)
                                        .collection('students')
                                        .snapshots(),
                                    builder: (context, studentsSnap) {
                                      final docs =
                                          studentsSnap.data?.docs ?? const [];
                                      final studentById = {
                                        for (final d in docs) d.id: d.data(),
                                      };

                                      final passengersList = passengers
                                          .map((e) => e.cast<String, dynamic>())
                                          .toList();
                                      debugPrint(
                                        'Monitor: fallback passengers=${passengersList.length} studentDocs=${studentById.length}',
                                      );
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _ensureSchoolTypesLoaded(
                                              studentById,
                                            );
                                            _ensureSchoolLocations(studentById);
                                          });
                                      debugPrint(
                                        'Monitor: fallback passengers list=$passengersList',
                                      );
                                      debugPrint(
                                        'Monitor: fallback studentDocKeys=${studentById.keys.toList()}',
                                      );
                                      debugPrint(
                                        'Monitor: driver has_home=${driver.containsKey('home_location')} has_service_area=${driver.containsKey('service_area')}',
                                      );
                                      final stopPoints =
                                          _buildRoutePolylineStops(
                                            routeType: routeType,
                                            driverData: driver,
                                            driverLivePoint:
                                                fallbackDriverPoint != null
                                                ? _roundLatLng(
                                                    fallbackDriverPoint,
                                                  )
                                                : null,
                                            passengers: passengersList,
                                            studentById: studentById,
                                          );

                                      debugPrint(
                                        'Monitor: computed stopPoints=${stopPoints.length} for routeType=$routeType (fallback)',
                                      );
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        debugPrint(
                                          'Monitor: calling _ensureRoutedPolyline for routeType=$routeType stopCount=${stopPoints.length}',
                                        );
                                        _ensureRoutedPolyline(
                                          routeType,
                                          stopPoints,
                                        );
                                      });

                                      final routed =
                                          _routedKey ==
                                              _makeRouteKey(
                                                routeType,
                                                stopPoints,
                                              )
                                          ? _routedPolyline
                                          : null;
                                      final polylinePoints =
                                          (routed != null && routed.length >= 2)
                                          ? routed
                                          : stopPoints;
                                      debugPrint(
                                        'Monitor: polylinePoints=${polylinePoints.length} usingRouted=${routed != null && routed.length >= 2}',
                                      );

                                      final usedKeys = <String>{};
                                      final routeMarkers =
                                          _buildRouteStopMarkers(
                                            stopPoints,
                                            usedKeys,
                                          );
                                      routeMarkers.addAll(
                                        _buildSchoolMarkers(
                                          tripId: tripId,
                                          routeType: routeType,
                                          passengers: passengersList,
                                          studentById: studentById,
                                          seenKeys: usedKeys,
                                        ),
                                      );
                                      if (parentPickupLocation != null &&
                                          usedKeys.add(
                                            _pointKey(parentPickupLocation),
                                          )) {
                                        routeMarkers.add(
                                          Marker(
                                            point: parentPickupLocation,
                                            width: 36,
                                            height: 36,
                                            child: const Icon(
                                              Icons.home,
                                              color: Colors.blue,
                                              size: 30,
                                            ),
                                          ),
                                        );
                                      }

                                      return Stack(
                                        children: [
                                          Positioned.fill(
                                            child: _buildMap(
                                              initialCenter: fallbackCenter,
                                              initialZoom:
                                                  fallbackDriverPoint != null
                                                  ? 15
                                                  : 2,
                                              heroTag:
                                                  'monitor_center_fallback',
                                              driverPoint: fallbackDriverPoint,
                                              polylinePoints: polylinePoints,
                                              markers: [
                                                ...routeMarkers,
                                                if (pickup != null)
                                                  Marker(
                                                    point: pickup,
                                                    width: 44,
                                                    height: 44,
                                                    child: const Icon(
                                                      Icons.home,
                                                      color: Colors.black87,
                                                      size: 34,
                                                    ),
                                                  ),
                                                if (fallbackDriverPoint != null)
                                                  Marker(
                                                    point: fallbackDriverPoint,
                                                    width: 44,
                                                    height: 44,
                                                    child: const Icon(
                                                      Icons.directions_bus,
                                                      color: Colors.blue,
                                                      size: 38,
                                                    ),
                                                  ),
                                              ],
                                              parentLocation:
                                                  parentPickupLocation,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.topCenter,
                                            child: _buildOverlayPanels(
                                              attending: attending,
                                              onAttendanceChanged: (v) =>
                                                  _parentService
                                                      .setAttendanceForToday(
                                                        parentId:
                                                            widget.parentId,
                                                        childId:
                                                            widget.childDoc.id,
                                                        attending: v,
                                                      ),
                                              statusText:
                                                  'Status: ${MonitorPage._statusLabel(status)}',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            }

                            final dp = driverPoint;

                            if (proximityAlertEnabled && pickup != null) {
                              final meters = const Distance()(pickup, dp);
                              if (meters <= 200 &&
                                  _proximityNotifiedTripId != tripId) {
                                _proximityNotifiedTripId = tripId;
                                final childName =
                                    (child['child_name'] ?? 'Student')
                                        .toString();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _notificationService.createUnique(
                                    notificationId:
                                        'proximity_${tripId}_${widget.childDoc.id}',
                                    userId: widget.parentId,
                                    type: 'proximity',
                                    message:
                                        'Driver is near pickup for $childName',
                                  );
                                });
                              }
                            }

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('drivers')
                                  .doc(assignedDriver)
                                  .collection('students')
                                  .snapshots(),
                              builder: (context, studentsSnap) {
                                final docs =
                                    studentsSnap.data?.docs ?? const [];
                                final studentById = {
                                  for (final d in docs) d.id: d.data(),
                                };

                                final passengersList = passengers
                                    .map((e) => e.cast<String, dynamic>())
                                    .toList();
                                debugPrint(
                                  'Monitor: active passengers=${passengersList.length} studentDocs=${studentById.length}',
                                );
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _ensureSchoolTypesLoaded(studentById);
                                  _ensureSchoolLocations(studentById);
                                });
                                debugPrint(
                                  'Monitor: active passengers list=$passengersList',
                                );
                                debugPrint(
                                  'Monitor: active studentDocKeys=${studentById.keys.toList()}',
                                );
                                debugPrint(
                                  'Monitor: driver has_home=${driver.containsKey('home_location')} has_service_area=${driver.containsKey('service_area')}',
                                );
                                final stopPoints = _buildRoutePolylineStops(
                                  routeType: routeType,
                                  driverData: driver,
                                  driverLivePoint: _roundLatLng(dp),
                                  passengers: passengersList,
                                  studentById: studentById,
                                );

                                debugPrint(
                                  'Monitor: computed stopPoints=${stopPoints.length} for routeType=$routeType (active)',
                                );
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  debugPrint(
                                    'Monitor: calling _ensureRoutedPolyline for routeType=$routeType stopCount=${stopPoints.length} (active)',
                                  );
                                  _ensureRoutedPolyline(routeType, stopPoints);
                                });

                                final routed =
                                    _routedKey ==
                                        _makeRouteKey(routeType, stopPoints)
                                    ? _routedPolyline
                                    : null;
                                final polylinePoints =
                                    (routed != null && routed.length >= 2)
                                    ? routed
                                    : stopPoints;
                                debugPrint(
                                  'Monitor: polylinePoints=${polylinePoints.length} usingRouted=${routed != null && routed.length >= 2}',
                                );

                                final usedKeys = <String>{};
                                final routeMarkers = _buildRouteStopMarkers(
                                  stopPoints,
                                  usedKeys,
                                );
                                routeMarkers.addAll(
                                  _buildSchoolMarkers(
                                    tripId: tripId,
                                    routeType: routeType,
                                    passengers: passengersList,
                                    studentById: studentById,
                                    seenKeys: usedKeys,
                                  ),
                                );
                                if (parentPickupLocation != null &&
                                    usedKeys.add(
                                      _pointKey(parentPickupLocation),
                                    )) {
                                  routeMarkers.add(
                                    Marker(
                                      point: parentPickupLocation,
                                      width: 36,
                                      height: 36,
                                      child: const Icon(
                                        Icons.home,
                                        color: Colors.blue,
                                        size: 30,
                                      ),
                                    ),
                                  );
                                }

                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _buildMap(
                                        initialCenter: center,
                                        initialZoom: 15,
                                        heroTag: 'monitor_center_active',
                                        driverPoint: dp,
                                        polylinePoints: polylinePoints,
                                        markers: [
                                          ...routeMarkers,
                                          if (pickup != null)
                                            Marker(
                                              point: pickup,
                                              width: 44,
                                              height: 44,
                                              child: const Icon(
                                                Icons.home,
                                                color: Colors.black87,
                                                size: 34,
                                              ),
                                            ),
                                          Marker(
                                            point: dp,
                                            width: 44,
                                            height: 44,
                                            child: const Icon(
                                              Icons.directions_bus,
                                              color: Colors.blue,
                                              size: 38,
                                            ),
                                          ),
                                        ],
                                        parentLocation: parentPickupLocation,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: _buildOverlayPanels(
                                        attending: attending,
                                        onAttendanceChanged: (v) =>
                                            _parentService
                                                .setAttendanceForToday(
                                                  parentId: widget.parentId,
                                                  childId: widget.childDoc.id,
                                                  attending: v,
                                                ),
                                        statusText:
                                            'Status: ${MonitorPage._statusLabel(status)}',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
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

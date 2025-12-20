import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import '../../models/boarding_status.dart';
import '../../services/notification_service.dart';
import '../../services/parent_service.dart';
import '../../services/live_location_service.dart';
import '../../services/trip_read_service.dart';

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
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
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
}

class _MonitorPageState extends State<MonitorPage> {
  final _parentService = ParentService();
  final _notificationService = NotificationService();

  String? _proximityNotifiedTripId;

  @override
  void initState() {
    super.initState();
    // SRS FR-PA-5.6: reset to Attending daily unless parent sets otherwise.
    _parentService.ensureAttendanceDefaultForToday(
      parentId: widget.parentId,
      childId: widget.childDoc.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final live = TripLiveLocationService();
    final trips = TripReadService();

    final childRef = db
        .collection('parents')
        .doc(widget.parentId)
        .collection('children')
        .doc(widget.childDoc.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _parentService.streamParent(widget.parentId),
      builder: (context, parentSnap) {
        final parent = parentSnap.data?.data() ?? const <String, dynamic>{};
        final notif =
            (parent['notifications'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final proximityAlertEnabled =
            (notif['proximity_alert'] as bool?) ?? true;

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

            final attendanceOverride =
                (child['attendance_override'] ?? 'attending').toString();
            final attending = attendanceOverride != 'absent';

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('drivers').doc(assignedDriver).snapshots(),
              builder: (context, driverSnap) {
                if (driverSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final driver = driverSnap.data?.data();
                final tripId = (driver?['active_trip_id'] ?? '').toString();
                if (tripId.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: SwitchListTile(
                          title: const Text('Attending today'),
                          subtitle: const Text(
                            'Set to Absent if not riding today',
                          ),
                          value: attending,
                          onChanged: (v) =>
                              _parentService.setAttendanceForToday(
                                parentId: widget.parentId,
                                childId: widget.childDoc.id,
                                attending: v,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(child: Text('No active service right now.')),
                    ],
                  );
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: trips.streamTrip(tripId),
                  builder: (context, tripSnap) {
                    final trip = tripSnap.data?.data();
                    final passengers =
                        (trip?['passengers'] as List?)?.cast<Map>() ??
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

                        return StreamBuilder(
                          stream: live.streamLiveLocation(tripId),
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
                              }
                            }

                            final pickup = MonitorPage._latLngFromMap(
                              (child['pickup_location'] as Map?)
                                  ?.cast<String, dynamic>(),
                            );

                            if (proximityAlertEnabled &&
                                tripId.isNotEmpty &&
                                pickup != null &&
                                driverPoint != null) {
                              final meters = const Distance()(
                                pickup,
                                driverPoint,
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

                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Card(
                                  child: SwitchListTile(
                                    title: const Text('Attending today'),
                                    subtitle: const Text(
                                      'Set to Absent if not riding today',
                                    ),
                                    value: attending,
                                    onChanged: (v) =>
                                        _parentService.setAttendanceForToday(
                                          parentId: widget.parentId,
                                          childId: widget.childDoc.id,
                                          attending: v,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Status: ${MonitorPage._statusLabel(status)}',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 260,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: FlutterMap(
                                      options: MapOptions(
                                        initialCenter: center,
                                        initialZoom: driverPoint != null
                                            ? 15
                                            : 2,
                                        interactionOptions:
                                            const InteractionOptions(
                                              flags:
                                                  InteractiveFlag.all &
                                                  ~InteractiveFlag.rotate,
                                            ),
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName: 'school_now',
                                        ),
                                        MarkerLayer(
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
                                        ),
                                      ],
                                    ),
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
  }
}

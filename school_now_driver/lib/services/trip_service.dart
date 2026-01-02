import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/trip.dart';
import '../models/trip_live_location.dart';
import '../models/boarding_status.dart';
import '../models/trip_passenger.dart';

class TripService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<void> _setBoardingStatusRtdb({
    required String tripId,
    required String studentId,
    required BoardingStatus status,
  }) async {
    final ref = _rtdb.ref('boarding_status/$tripId/$studentId');
    await ref.set({
      'status': BoardingStatusCodec.toJson(status),
      'last_update': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Streams the active trip document for a driver.
  ///
  /// Uses `drivers/<driverId>.active_trip_id` as a pointer so we avoid
  /// composite index requirements.
  Stream<DocumentSnapshot<Map<String, dynamic>>?> streamActiveTripForDriver(
    String driverId,
  ) {
    return _db.collection('drivers').doc(driverId).snapshots().asyncExpand((
      driverSnap,
    ) {
      final tripId = (driverSnap.data()?['active_trip_id'] ?? '').toString();
      if (tripId.isEmpty) {
        return Stream.value(null);
      }
      return _db.collection('trips').doc(tripId).snapshots();
    });
  }

  Future<String> createTrip({
    required String driverId,
    required String vehicleId,
    required String routeId,
    String routeType = 'morning',
    List<String> studentIds = const [],
  }) async {
    final tripRef = _db.collection('trips').doc();
    final tripId = tripRef.id;
    final liveLocationPath = TripLiveLocation.pathForTrip(tripId);

    final trip = Trip(
      id: tripId,
      driverId: driverId,
      vehicleId: vehicleId,
      routeId: routeId,
      routeType: routeType,
      status: TripStatus.planned,
      passengers: studentIds
          .map(
            (id) => TripPassenger(
              studentId: id,
              status: BoardingStatus.notBoarded,
              updatedAt: DateTime.now(),
            ),
          )
          .toList(),
      liveLocationPath: liveLocationPath,
    );

    await tripRef.set(trip.toJson());

    await _db.collection('drivers').doc(driverId).set({
      'active_trip_id': tripId,
      'active_trip_status': 'planned',
      'active_trip_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return tripId;
  }

  Future<void> startTrip(String tripId) async {
    final ref = _db.collection('trips').doc(tripId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final driverId = (snap.data()?['driver_id'] ?? '').toString();

      tx.update(ref, {
        'status': 'in_progress',
        'start_time_ms': DateTime.now().millisecondsSinceEpoch,
      });

      if (driverId.isNotEmpty) {
        tx.set(_db.collection('drivers').doc(driverId), {
          'active_trip_id': tripId,
          'active_trip_status': 'in_progress',
          'active_trip_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> updatePassengerStatus(
    String tripId,
    String studentId,
    BoardingStatus status,
  ) async {
    final trip = await _db.collection('trips').doc(tripId).get();
    final data = trip.data() as Map<String, dynamic>;
    final passengers =
        (data['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final updated = passengers.map((p) {
      if (p['student_id'] == studentId) {
        return {
          ...p,
          'status': BoardingStatusCodec.toJson(status),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };
      }
      return p;
    }).toList();

    await _db.collection('trips').doc(tripId).update({'passengers': updated});

    // Best-effort RTDB mirror.
    try {
      await _setBoardingStatusRtdb(
        tripId: tripId,
        studentId: studentId,
        status: status,
      );
    } catch (_) {}
  }

  Future<void> upsertPassengerStatus(
    String tripId,
    String studentId,
    BoardingStatus status,
  ) async {
    final ref = _db.collection('trips').doc(tripId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final passengers =
          (data['passengers'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      bool updatedExisting = false;
      final nextPassengers = passengers.map((p) {
        if ((p['student_id'] ?? '').toString() == studentId) {
          updatedExisting = true;
          return {
            ...p,
            'status': BoardingStatusCodec.toJson(status),
            'updated_at': nowMs,
          };
        }
        return p;
      }).toList();

      if (!updatedExisting) {
        nextPassengers.add({
          'student_id': studentId,
          'status': BoardingStatusCodec.toJson(status),
          'updated_at': nowMs,
        });
      }

      tx.update(ref, {'passengers': nextPassengers});
    });

    // Best-effort RTDB mirror.
    try {
      await _setBoardingStatusRtdb(
        tripId: tripId,
        studentId: studentId,
        status: status,
      );
    } catch (_) {}
  }

  Future<void> endTrip(String tripId) async {
    final ref = _db.collection('trips').doc(tripId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final driverId = (snap.data()?['driver_id'] ?? '').toString();

      tx.update(ref, {
        'status': 'completed',
        'end_time_ms': DateTime.now().millisecondsSinceEpoch,
      });

      if (driverId.isNotEmpty) {
        tx.set(_db.collection('drivers').doc(driverId), {
          'active_trip_id': FieldValue.delete(),
          'active_trip_status': FieldValue.delete(),
          'active_trip_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Marks all passengers as arrived at school (morning flow).
  ///
  /// Keeps `absent` passengers as-is; everything else becomes `alighted`.
  Future<void> markAllArrivedAtSchool(String tripId) async {
    final ref = _db.collection('trips').doc(tripId);
    final toMirror = <({String studentId, BoardingStatus status})>[];
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final passengers =
          (data['passengers'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final updatedPassengers = passengers.map((p) {
        final status = BoardingStatusCodec.fromJson(
          (p['status'] ?? 'not_boarded').toString(),
        );
        if (status == BoardingStatus.absent) {
          return p;
        }
        final studentId = (p['student_id'] ?? '').toString();
        if (studentId.isNotEmpty) {
          toMirror.add((studentId: studentId, status: BoardingStatus.alighted));
        }
        return {
          ...p,
          'status': BoardingStatusCodec.toJson(BoardingStatus.alighted),
          'updated_at': nowMs,
        };
      }).toList();

      tx.update(ref, {
        'passengers': updatedPassengers,
        'arrival_school_time_ms': nowMs,
      });
    });

    // Best-effort RTDB mirror for all.
    for (final e in toMirror) {
      try {
        await _setBoardingStatusRtdb(
          tripId: tripId,
          studentId: e.studentId,
          status: e.status,
        );
      } catch (_) {}
    }
  }

  /// Marks the provided students as arrived at school (morning flow) for a given trip.
  ///
  /// Only updates students whose current status is not `absent`.
  Future<void> markStudentsArrivedAtSchool(
    String tripId,
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return;
    final ref = _db.collection('trips').doc(tripId);
    final toMirror = <({String studentId, BoardingStatus status})>[];

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final passengers =
          (data['passengers'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final updatedPassengers = passengers.map((p) {
        final studentId = (p['student_id'] ?? '').toString();
        if (!studentIds.contains(studentId)) return p;
        final status = BoardingStatusCodec.fromJson(
          (p['status'] ?? 'not_boarded').toString(),
        );
        if (status == BoardingStatus.absent) return p;
        toMirror.add((studentId: studentId, status: BoardingStatus.alighted));
        return {
          ...p,
          'status': BoardingStatusCodec.toJson(BoardingStatus.alighted),
          'updated_at': nowMs,
        };
      }).toList();

      tx.update(ref, {
        'passengers': updatedPassengers,
        'arrival_school_time_ms': nowMs,
      });
    });

    // Best-effort RTDB mirror for updated students.
    for (final e in toMirror) {
      try {
        await _setBoardingStatusRtdb(
          tripId: tripId,
          studentId: e.studentId,
          status: e.status,
        );
      } catch (_) {}
    }
  }
}

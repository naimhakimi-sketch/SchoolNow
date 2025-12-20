import 'package:cloud_firestore/cloud_firestore.dart';

class ParentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _todayYmd() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DocumentReference<Map<String, dynamic>> parentRef(String parentId) => _db.collection('parents').doc(parentId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamParent(String parentId) => parentRef(parentId).snapshots();

  Future<Map<String, dynamic>?> getParent(String parentId) async {
    final snap = await parentRef(parentId).get();
    return snap.data();
  }

  Future<void> updateParent(String parentId, Map<String, dynamic> patch) async {
    await parentRef(parentId).set(
      {
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  CollectionReference<Map<String, dynamic>> childrenRef(String parentId) => parentRef(parentId).collection('children');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamChildren(String parentId) {
    return childrenRef(parentId).orderBy('created_at', descending: true).snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addChild({
    required String parentId,
    required String childName,
    required String childIcNumber,
    required String schoolName,
    double? schoolLat,
    double? schoolLng,
  }) async {
    final normalizedChildIc = childIcNumber.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

    Map<String, dynamic>? pickupLocation;
    final parentSnap = await parentRef(parentId).get();
    final parent = parentSnap.data();
    final pickup = (parent?['pickup_location'] as Map?)?.cast<String, dynamic>();
    if (pickup != null && pickup['lat'] != null && pickup['lng'] != null) {
      pickupLocation = {'lat': pickup['lat'], 'lng': pickup['lng']};
    }

    final ref = childrenRef(parentId).doc();
    await ref.set({
      'child_name': childName,
      'child_ic': childIcNumber.trim(),
      'child_ic_normalized': normalizedChildIc,
      'school_name': schoolName.trim(),
      'school_lat': schoolLat,
      'school_lng': schoolLng,
      'pickup_location': pickupLocation,
      'assigned_driver_id': null,
      // SRS FR-PA-5.6: default attendance resets daily.
      'attendance_override': 'attending',
      'attendance_date_ymd': _todayYmd(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref;
  }

  Future<void> updateChild({
    required String parentId,
    required String childId,
    required String childName,
    required String childIcNumber,
    required String schoolName,
    double? schoolLat,
    double? schoolLng,
    double? pickupLat,
    double? pickupLng,
  }) async {
    final normalizedChildIc = childIcNumber.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

    final childRef = childrenRef(parentId).doc(childId);
    final snap = await childRef.get();
    final existing = snap.data() ?? const <String, dynamic>{};
    final assignedDriverId = (existing['assigned_driver_id'] ?? '').toString();

    final batch = _db.batch();
    batch.set(
      childRef,
      {
        'child_name': childName,
        'child_ic': childIcNumber.trim(),
        'child_ic_normalized': normalizedChildIc,
        'school_name': schoolName.trim(),
        'school_lat': schoolLat,
        'school_lng': schoolLng,
        'pickup_location': (pickupLat != null && pickupLng != null)
            ? {
                'lat': pickupLat,
                'lng': pickupLng,
              }
            : null,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db.collection('drivers').doc(assignedDriverId).collection('students').doc(childId);
      batch.set(
        driverStudentRef,
        {
          'student_name': childName,
          'pickup_location': (pickupLat != null && pickupLng != null)
              ? {
                  'lat': pickupLat,
                  'lng': pickupLng,
                }
              : null,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> ensureAttendanceDefaultForToday({
    required String parentId,
    required String childId,
  }) async {
    final childRef = childrenRef(parentId).doc(childId);
    final childSnap = await childRef.get();
    final child = childSnap.data();
    if (child == null) return;

    final today = _todayYmd();
    final existingDate = (child['attendance_date_ymd'] ?? '').toString();
    if (existingDate == today) return;

    final assignedDriverId = (child['assigned_driver_id'] ?? '').toString();
    final batch = _db.batch();
    batch.set(
      childRef,
      {
        'attendance_override': 'attending',
        'attendance_date_ymd': today,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db.collection('drivers').doc(assignedDriverId).collection('students').doc(childId);
      batch.set(
        driverStudentRef,
        {
          'attendance_override': 'attending',
          'attendance_date_ymd': today,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> setAttendanceForToday({
    required String parentId,
    required String childId,
    required bool attending,
  }) async {
    final today = _todayYmd();
    final childRef = childrenRef(parentId).doc(childId);
    final childSnap = await childRef.get();
    final child = childSnap.data();
    if (child == null) return;

    final assignedDriverId = (child['assigned_driver_id'] ?? '').toString();
    final value = attending ? 'attending' : 'absent';

    final batch = _db.batch();
    batch.set(
      childRef,
      {
        'attendance_override': value,
        'attendance_date_ymd': today,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db.collection('drivers').doc(assignedDriverId).collection('students').doc(childId);
      batch.set(
        driverStudentRef,
        {
          'attendance_override': value,
          'attendance_date_ymd': today,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> setAssignedDriver({
    required String parentId,
    required String childId,
    required String? driverId,
  }) async {
    await childrenRef(parentId).doc(childId).set(
      {
        'assigned_driver_id': driverId,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

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

  DocumentReference<Map<String, dynamic>> parentRef(String parentId) =>
      _db.collection('parents').doc(parentId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamParent(
    String parentId,
  ) => parentRef(parentId).snapshots();

  Future<Map<String, dynamic>?> getParent(String parentId) async {
    final snap = await parentRef(parentId).get();
    return snap.data();
  }

  Future<void> updateParent(String parentId, Map<String, dynamic> patch) async {
    // If pickup_location is being updated, also update all children
    if (patch.containsKey('pickup_location')) {
      final childrenSnap = await childrenRef(parentId).get();
      final batch = _db.batch();

      // Update parent
      batch.set(parentRef(parentId), {
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update all children with new pickup location
      for (final childDoc in childrenSnap.docs) {
        final childId = childDoc.id;
        final childData = childDoc.data();
        final assignedDriverId =
            (childData['assigned_driver_id'] as String?) ?? '';

        batch.update(childDoc.reference, {
          'pickup_location': patch['pickup_location'],
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Also update the driver's cached student record if assigned
        if (assignedDriverId.isNotEmpty) {
          final driverStudentRef = _db
              .collection('drivers')
              .doc(assignedDriverId)
              .collection('students')
              .doc(childId);
          batch.update(driverStudentRef, {
            'pickup_location': patch['pickup_location'],
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } else {
      // Normal update without pickup_location change
      await parentRef(parentId).set({
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  CollectionReference<Map<String, dynamic>> childrenRef(String parentId) =>
      parentRef(parentId).collection('children');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamChildren(String parentId) {
    return childrenRef(
      parentId,
    ).orderBy('created_at', descending: true).snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addChild({
    required String parentId,
    required String childName,
    required String childIcNumber,
    required String schoolName,
    required String schoolId,
  }) async {
    final normalizedChildIc = childIcNumber
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
        .toUpperCase();

    // Get parent's pickup location
    final parentDoc = await _db.collection('parents').doc(parentId).get();
    final parentData = parentDoc.data();
    final pickupLocation = parentData?['pickup_location'];

    final ref = childrenRef(parentId).doc();
    await ref.set({
      'child_name': childName,
      'child_ic': childIcNumber.trim(),
      'child_ic_normalized': normalizedChildIc,
      'school_name': schoolName.trim(),
      'school_id': schoolId,
      'assigned_driver_id': null,
      'attendance_override': 'attending',
      'attendance_date_ymd': _todayYmd(),
      'pickup_location': pickupLocation,
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
    required String schoolId,
  }) async {
    final normalizedChildIc = childIcNumber
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
        .toUpperCase();

    final childRef = childrenRef(parentId).doc(childId);
    final snap = await childRef.get();
    final existing = snap.data() ?? const <String, dynamic>{};
    final assignedDriverId = (existing['assigned_driver_id'] ?? '').toString();

    final batch = _db.batch();
    batch.set(childRef, {
      'child_name': childName,
      'child_ic': childIcNumber.trim(),
      'child_ic_normalized': normalizedChildIc,
      'school_name': schoolName.trim(),
      'school_id': schoolId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db
          .collection('drivers')
          .doc(assignedDriverId)
          .collection('students')
          .doc(childId);
      batch.set(driverStudentRef, {
        'student_name': childName,
        'school_id': schoolId,
        'school_name': schoolName.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    batch.set(childRef, {
      'attendance_override': value,
      'attendance_date_ymd': today,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db
          .collection('drivers')
          .doc(assignedDriverId)
          .collection('students')
          .doc(childId);
      batch.set(driverStudentRef, {
        'attendance_override': value,
        'attendance_date_ymd': today,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> setAssignedDriver({
    required String parentId,
    required String childId,
    required String? driverId,
  }) async {
    await childrenRef(parentId).doc(childId).set({
      'assigned_driver_id': driverId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    batch.set(childRef, {
      'attendance_override': 'attending',
      'attendance_date_ymd': today,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (assignedDriverId.isNotEmpty) {
      final driverStudentRef = _db
          .collection('drivers')
          .doc(assignedDriverId)
          .collection('students')
          .doc(childId);
      batch.set(driverStudentRef, {
        'attendance_override': 'attending',
        'attendance_date_ymd': today,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}

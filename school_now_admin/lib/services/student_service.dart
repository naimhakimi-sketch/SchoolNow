import 'package:cloud_firestore/cloud_firestore.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all children from all parents as a unified student list
  /// SOURCE OF TRUTH: parents/{parentId}/children/{childId}
  Future<List<Map<String, dynamic>>> getAllChildrenAsStudents() async {
    final parentsSnap = await _firestore.collection('parents').get();
    List<Map<String, dynamic>> students = [];
    for (final parentDoc in parentsSnap.docs) {
      final parentId = parentDoc.id;
      final parentName = parentDoc['name'] ?? '';
      final childrenSnap = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .get();
      for (final childDoc in childrenSnap.docs) {
        final data = childDoc.data();
        students.add({
          'id': childDoc.id,
          'parent_id': parentId,
          'parent_name': parentName,
          'name': data['child_name'] ?? '',
          'ic': data['child_ic'] ?? '',
          'school_name': data['school_name'] ?? '',
          'school_id': data['school_id'] ?? '',
          'assigned_driver_id': data['assigned_driver_id'],
          'attendance_date_ymd': data['attendance_date_ymd'],
          'attendance_override': data['attendance_override'],
          'pickup_location': data['pickup_location'],
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
          'from_children':
              true, // Mark to distinguish from independent students
        });
      }
    }
    return students;
  }

  /// Add a new child to a parent
  /// This creates the single source of truth for the student
  Future<void> addStudent({
    required String name,
    required String parentId,
    required String schoolId,
    String? driverId,
    String? grade,
    String? section,
  }) async {
    // Validate parent exists
    final parentDoc = await _firestore
        .collection('parents')
        .doc(parentId)
        .get();
    if (!parentDoc.exists) {
      throw Exception('Parent does not exist');
    }

    // Validate school exists
    final schoolDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .get();
    if (!schoolDoc.exists) {
      throw Exception('School does not exist');
    }

    // Get parent details for reference
    final parentData = parentDoc.data() as Map<String, dynamic>;
    final parentName = parentData['name'] ?? 'Unknown';

    // Create child document in parent's children subcollection
    final childRef = await _firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .add({
          'child_name': name,
          'child_ic': '',
          'child_ic_normalized': '',
          'school_name': schoolDoc['name'] ?? '',
          'school_id': schoolId,
          'assigned_driver_id': driverId ?? '',
          'attendance_override': 'attending',
          'attendance_date_ymd': '',
          'pickup_location': parentData['pickup_location'] ?? {},
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

    // If driver is assigned, add to driver's students collection (as cache)
    if (driverId != null && driverId.isNotEmpty) {
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('students')
          .doc(childRef.id)
          .set({
            'student_name': name,
            'parent_name': parentName,
            'contact_number': parentData['contact_number'] ?? '',
            'parent_id': parentId,
            'pickup_location': parentData['pickup_location'] ?? {},
            'attendance_override': 'attending',
            'attendance_date_ymd': '',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
  }

  /// Update a child in parent's collection
  /// Syncs to driver's students collection if driver is assigned
  Future<void> updateStudent({
    required String studentId,
    required String parentId,
    required String name,
    required String schoolId,
    String? driverId,
  }) async {
    final childRef = _firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(studentId);

    final batch = _firestore.batch();

    // Update child in parent's collection
    batch.set(childRef, {
      'child_name': name,
      'school_id': schoolId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Get old data to check if driver assignment changed
    final oldDoc = await childRef.get();
    final oldDriverId = (oldDoc.data()?['assigned_driver_id'] ?? '').toString();

    // Update driver's students collection if driver is assigned
    if (driverId != null && driverId.isNotEmpty) {
      final driverStudentRef = _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('students')
          .doc(studentId);
      batch.set(driverStudentRef, {
        'student_name': name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Remove from old driver if reassigned
    if (oldDriverId.isNotEmpty && oldDriverId != driverId) {
      final oldDriverRef = _firestore
          .collection('drivers')
          .doc(oldDriverId)
          .collection('students')
          .doc(studentId);
      batch.delete(oldDriverRef);
    }

    await batch.commit();
  }

  /// Delete a child from parent's collection
  /// Also cleans up driver's students collection and checks for conflicts
  Future<void> deleteStudent(String parentId, String studentId) async {
    // Check for related payments
    final paymentsSnapshot = await _firestore
        .collection('payments')
        .where('child_id', isEqualTo: studentId)
        .get();

    if (paymentsSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete student with existing payments');
    }

    // Get the student to find assigned driver
    final childDoc = await _firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(studentId)
        .get();

    final driverId = (childDoc.data()?['assigned_driver_id'] ?? '').toString();

    // Delete with batch to ensure consistency
    final batch = _firestore.batch();

    // Delete from parent's children
    batch.delete(childDoc.reference);

    // Remove from driver's students if assigned
    if (driverId.isNotEmpty) {
      final driverStudentRef = _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('students')
          .doc(studentId);
      batch.delete(driverStudentRef);
    }

    await batch.commit();
  }

  /// Get parent details
  Future<DocumentSnapshot> getParent(String parentId) {
    return _firestore.collection('parents').doc(parentId).get();
  }

  /// Get school details
  Future<DocumentSnapshot> getSchool(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).get();
  }

  /// Get driver details
  Future<DocumentSnapshot?> getDriver(String? driverId) {
    if (driverId == null || driverId.isEmpty) return Future.value(null);
    return _firestore.collection('drivers').doc(driverId).get();
  }

  /// Get all parents for dropdown
  Future<List<Map<String, dynamic>>> getAllParents() async {
    final snapshot = await _firestore
        .collection('parents')
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'] ?? 'Unknown',
        'email': doc['email'] ?? '',
      };
    }).toList();
  }

  /// Get all schools for dropdown
  Future<List<Map<String, dynamic>>> getAllSchools() async {
    final snapshot = await _firestore
        .collection('schools')
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'] ?? 'Unknown',
        'type': doc['type'] ?? '',
      };
    }).toList();
  }

  /// Get available drivers for dropdown
  Future<List<Map<String, dynamic>>> getAvailableDrivers() async {
    final snapshot = await _firestore
        .collection('drivers')
        .where('is_verified', isEqualTo: true)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'assigned_bus_id': data['assigned_bus_id'] ?? 'No bus',
      };
    }).toList();
  }

  /// Search students in parent's children collections
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final allStudents = await getAllChildrenAsStudents();
    return allStudents
        .where(
          (student) => (student['name'] as String).toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
  }
}

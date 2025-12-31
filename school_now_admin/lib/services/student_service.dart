import 'package:cloud_firestore/cloud_firestore.dart';

class StudentService {
  // Get all children from all parents and map to student-like structure
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
          'school_lat': data['school_lat'],
          'school_lng': data['school_lng'],
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        });
      }
    }
    return students;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all students
  Stream<QuerySnapshot> getStudentsStream() {
    return _firestore.collection('students').orderBy('name').snapshots();
  }

  // Get students by parent
  Stream<QuerySnapshot> getStudentsByParent(String parentId) {
    return _firestore
        .collection('students')
        .where('parent_id', isEqualTo: parentId)
        .snapshots();
  }

  // Get students by school
  Stream<QuerySnapshot> getStudentsBySchool(String schoolId) {
    return _firestore
        .collection('students')
        .where('school_id', isEqualTo: schoolId)
        .snapshots();
  }

  // Add student
  Future<void> addStudent({
    required String name,
    required String parentId,
    required String schoolId,
    String? driverId,
    String? grade,
    String? section,
  }) async {
    await _firestore.collection('students').add({
      'name': name,
      'parent_id': parentId,
      'school_id': schoolId,
      'driver_id': driverId,
      'grade': grade,
      'section': section,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Update student
  Future<void> updateStudent({
    required String studentId,
    required String name,
    required String parentId,
    required String schoolId,
    String? driverId,
    String? grade,
    String? section,
  }) async {
    await _firestore.collection('students').doc(studentId).update({
      'name': name,
      'parent_id': parentId,
      'school_id': schoolId,
      'driver_id': driverId,
      'grade': grade,
      'section': section,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete student
  Future<void> deleteStudent(String studentId) async {
    // Check for related payments
    final paymentsSnapshot = await _firestore
        .collection('payments')
        .where('student_id', isEqualTo: studentId)
        .get();

    if (paymentsSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete student with existing payments');
    }

    await _firestore.collection('students').doc(studentId).delete();
  }

  // Get parent details
  Future<DocumentSnapshot> getParent(String parentId) {
    return _firestore.collection('parents').doc(parentId).get();
  }

  // Get school details
  Future<DocumentSnapshot> getSchool(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).get();
  }

  // Get driver details
  Future<DocumentSnapshot?> getDriver(String? driverId) {
    if (driverId == null || driverId.isEmpty) return Future.value(null);
    return _firestore.collection('drivers').doc(driverId).get();
  }

  // Get all parents for dropdown
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

  // Get all schools for dropdown
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

  // Get available drivers for dropdown
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
        'bus_plate': data.containsKey('plate_number')
            ? data['plate_number']
            : 'No bus',
      };
    }).toList();
  }

  // Search students
  Future<List<DocumentSnapshot>> searchStudents(String query) async {
    final snapshot = await _firestore.collection('students').get();
    return snapshot.docs.where((doc) {
      final name = (doc['name'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDriverService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getDrivers() {
    return _db.collection('drivers').snapshots();
  }

  Future<DocumentSnapshot> getDriverById(String driverId) {
    return _db.collection('drivers').doc(driverId).get();
  }

  Future<void> addDriver({
    required String icNumber,
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    required double monthlyFee,
    String? assignedBusId,
    List<String>? assignedSchoolIds,
    Map<String, dynamic>? serviceArea,
  }) async {
    final driverRef = await _db.collection('drivers').add({
      'ic_number': icNumber,
      'name': name,
      'email': email,
      'contact_number': contactNumber,
      'license_number': licenseNumber,
      'monthly_fee': monthlyFee,
      'role': 'driver',
      'is_verified': false,
      'is_searchable': false,
      if (assignedBusId != null) 'assigned_bus_id': assignedBusId,
      'assigned_school_ids': assignedSchoolIds ?? [],
      if (serviceArea != null) 'service_area': serviceArea,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update bus with assigned driver
    if (assignedBusId != null) {
      await _db.collection('buses').doc(assignedBusId).update({
        'assigned_driver_id': driverRef.id,
      });
    }
  }

  Future<void> updateDriver(String id, Map<String, dynamic> patch) async {
    patch['updated_at'] = FieldValue.serverTimestamp();

    // Handle bus reassignment
    if (patch.containsKey('assigned_bus_id')) {
      // Get current driver data
      final driverDoc = await _db.collection('drivers').doc(id).get();
      final currentBusId = driverDoc.data()?['assigned_bus_id'];
      final dynamic busField = patch['assigned_bus_id'];
      // If FieldValue.delete(), treat as null for bus reassignment logic
      final String? newBusId = (busField is String) ? busField : null;

      // Remove driver from old bus if changed
      if (currentBusId != null && currentBusId != newBusId) {
        await _db.collection('buses').doc(currentBusId).update({
          'assigned_driver_id': null,
        });
      }

      // Assign driver to new bus
      if (newBusId != null) {
        await _db.collection('buses').doc(newBusId).update({
          'assigned_driver_id': id,
        });
      } else {
        // If unassigned, make sure to remove assigned_driver_id from old bus
        if (currentBusId != null) {
          await _db.collection('buses').doc(currentBusId).update({
            'assigned_driver_id': null,
          });
        }
      }
    }

    await _db.collection('drivers').doc(id).update(patch);
  }

  Future<void> deleteDriver(String id) async {
    // Check if driver has assigned students (match UI logic)
    final studentsSnap = await _db
        .collection('students')
        .where('driver_id', isEqualTo: id)
        .limit(1)
        .get();

    if (studentsSnap.docs.isNotEmpty) {
      throw Exception('Cannot delete driver: Driver has assigned students');
    }

    // Get driver data to unassign bus
    final driverDoc = await _db.collection('drivers').doc(id).get();
    final busId = driverDoc.data()?['assigned_bus_id'];

    // Unassign bus
    if (busId != null) {
      await _db.collection('buses').doc(busId).update({
        'assigned_driver_id': null,
      });
    }

    await _db.collection('drivers').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getAvailableSchools() async {
    final snapshot = await _db.collection('schools').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}

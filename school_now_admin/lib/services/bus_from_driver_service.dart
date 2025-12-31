import 'package:cloud_firestore/cloud_firestore.dart';

class BusService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getBuses() {
    return _db.collection('buses').snapshots();
  }

  Future<void> addBus({
    required String plateNumber,
    required int capacity,
  }) async {
    // Use plate number as document ID (normalized - uppercase, no spaces)
    final docId = plateNumber.toUpperCase().replaceAll(' ', '');

    await _db.collection('buses').doc(docId).set({
      'plate_number': plateNumber.toUpperCase(),
      'capacity': capacity,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBus({
    required String busId,
    required String plateNumber,
    required int capacity,
  }) async {
    await _db.collection('buses').doc(busId).update({
      'plate_number': plateNumber.toUpperCase(),
      'capacity': capacity,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBus(String busId) async {
    // Check if bus is assigned to any driver
    final driversWithBus = await _db
        .collection('drivers')
        .where('assigned_bus_id', isEqualTo: busId)
        .limit(1)
        .get();

    if (driversWithBus.docs.isNotEmpty) {
      throw Exception('Cannot delete bus: It is assigned to a driver');
    }

    await _db.collection('buses').doc(busId).delete();
  }

  Future<List<Map<String, dynamic>>> getAvailableBuses() async {
    final snapshot = await _db.collection('buses').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}

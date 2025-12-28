import 'package:cloud_firestore/cloud_firestore.dart';

class BusFromDriverService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getBuses() {
    return _db
        .collection('drivers')
        .where('role', isEqualTo: 'driver')
        .snapshots();
  }

  Future<void> updateBusCapacity(String driverId, int capacity) {
    return _db.collection('drivers').doc(driverId).update({
      'seat_capacity': capacity,
    });
  }
}

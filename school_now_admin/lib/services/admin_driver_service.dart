import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDriverService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getDrivers() {
    return _db.collection('drivers').snapshots();
  }

  Future<void> updateDriver(String id, Map<String, dynamic> patch) async {
    await _db.collection('drivers').doc(id).update(patch);
  }
}

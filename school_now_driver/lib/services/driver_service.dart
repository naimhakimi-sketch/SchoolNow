import 'package:cloud_firestore/cloud_firestore.dart';

class DriverService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDriver(String driverId) {
    return _db.collection('drivers').doc(driverId).snapshots();
  }

  Future<Map<String, dynamic>?> getDriver(String driverId) async {
    final snap = await _db.collection('drivers').doc(driverId).get();
    return snap.data();
  }

  Future<void> updateDriver(String driverId, Map<String, dynamic> patch) async {
    await _db.collection('drivers').doc(driverId).set(
      {
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

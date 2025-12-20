import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class TripReadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTrip(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots();
  }

  Future<void> updatePassengerStatus({
    required String tripId,
    required String studentId,
    required String status,
  }) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(tripRef);
      final data = snap.data();
      if (data == null) {
        throw StateError('Trip not found');
      }

      final passengers = (data['passengers'] as List?)?.cast<Map>() ?? <Map>[];
      var found = false;
      final updated = passengers.map((p) {
        final m = p.cast<String, dynamic>();
        if ((m['student_id'] ?? '').toString() == studentId) {
          found = true;
          return {
            ...m,
            'status': status,
            // Keep type consistent with driver writes (int milliseconds).
            'updated_at': nowMs,
          };
        }
        return m;
      }).toList();

      if (!found) {
        throw StateError('Student not found in this trip');
      }

      tx.set(tripRef, {'passengers': updated}, SetOptions(merge: true));
    });

    // Best-effort RTDB mirror for real-time boarding status.
    try {
      await _rtdb.ref('boarding_status/$tripId/$studentId').set({
        'status': status,
        'last_update': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}

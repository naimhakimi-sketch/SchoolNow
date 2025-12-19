import 'package:cloud_firestore/cloud_firestore.dart';

class RequestPaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get payments => _db.collection('payments');

  Future<String> createPayment({
    required String parentId,
    required String driverId,
    required String childId,
    required num amount,
    Map<String, dynamic>? metadata,
  }) async {
    final ref = payments.doc();
    await ref.set({
      'parent_id': parentId,
      'driver_id': driverId,
      'child_id': childId,
      'amount': amount,
      if (metadata != null) 'metadata': metadata,
      // SRS: Pending after payment.
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> setPaymentStatus(String paymentId, String status) async {
    await payments.doc(paymentId).set(
      {
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> createServiceRequest({
    required String driverId,
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    final ref = _db.collection('drivers').doc(driverId).collection('service_requests').doc(requestId);
    await ref.set(payload, SetOptions(merge: true));
    return ref.id;
  }
}

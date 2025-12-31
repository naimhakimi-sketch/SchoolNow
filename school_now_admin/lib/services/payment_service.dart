import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPayments() {
    return _db
        .collection('payments')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPaymentsByStatus(String status) {
    return _db
        .collection('payments')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> getPaymentStatistics() async {
    final allPayments = await _db.collection('payments').get();

    int totalPayments = allPayments.docs.length;
    int pending = 0;
    int completed = 0;
    int refunded = 0;
    double totalAmount = 0;
    double completedAmount = 0;

    for (final doc in allPayments.docs) {
      final data = doc.data();
      final status = data['status'] ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;

      totalAmount += amount;

      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'completed':
          completed++;
          completedAmount += amount;
          break;
        case 'refunded':
          refunded++;
          break;
      }
    }

    return {
      'total': totalPayments,
      'pending': pending,
      'completed': completed,
      'refunded': refunded,
      'totalAmount': totalAmount,
      'completedAmount': completedAmount,
    };
  }

  Future<void> updatePaymentStatus(String paymentId, String status) async {
    await _db.collection('payments').doc(paymentId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String> getParentName(String parentId) async {
    final doc = await _db.collection('parents').doc(parentId).get();
    if (!doc.exists) return 'Unknown';
    return doc.data()?['name'] ?? 'Unknown';
  }

  Future<String> getDriverName(String driverId) async {
    final doc = await _db.collection('drivers').doc(driverId).get();
    if (!doc.exists) return 'Unknown';
    return doc.data()?['name'] ?? 'Unknown';
  }
}

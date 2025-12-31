import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getSystemStatistics() async {
    // Get counts
    final driversSnap = await _db.collection('drivers').get();
    final parentsSnap = await _db.collection('parents').get();
    final schoolsSnap = await _db.collection('schools').get();
    final paymentsSnap = await _db.collection('payments').get();

    // Count verified drivers
    int verifiedDrivers = 0;
    int unverifiedDrivers = 0;
    for (final doc in driversSnap.docs) {
      final verified = doc.data()['is_verified'] == true;
      if (verified) {
        verifiedDrivers++;
      } else {
        unverifiedDrivers++;
      }
    }

    // Count students across all parents
    int totalStudents = 0;
    for (final parentDoc in parentsSnap.docs) {
      final childrenSnap = await _db
          .collection('parents')
          .doc(parentDoc.id)
          .collection('children')
          .get();
      totalStudents += childrenSnap.docs.length;
    }

    // Calculate payment statistics
    double totalRevenue = 0;
    int completedPayments = 0;
    int pendingPayments = 0;
    for (final doc in paymentsSnap.docs) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      final status = doc.data()['status'] ?? '';

      if (status == 'completed') {
        totalRevenue += amount;
        completedPayments++;
      } else if (status == 'pending') {
        pendingPayments++;
      }
    }

    // Get service requests statistics
    final requestsSnap = await _db.collectionGroup('service_requests').get();
    int pendingRequests = 0;
    int approvedRequests = 0;
    int rejectedRequests = 0;

    for (final doc in requestsSnap.docs) {
      final status = doc.data()['status'] ?? '';
      switch (status) {
        case 'pending':
          pendingRequests++;
          break;
        case 'approved':
          approvedRequests++;
          break;
        case 'rejected':
          rejectedRequests++;
          break;
      }
    }

    return {
      'totalDrivers': driversSnap.docs.length,
      'verifiedDrivers': verifiedDrivers,
      'unverifiedDrivers': unverifiedDrivers,
      'totalParents': parentsSnap.docs.length,
      'totalStudents': totalStudents,
      'totalSchools': schoolsSnap.docs.length,
      'totalRevenue': totalRevenue,
      'completedPayments': completedPayments,
      'pendingPayments': pendingPayments,
      'pendingRequests': pendingRequests,
      'approvedRequests': approvedRequests,
      'rejectedRequests': rejectedRequests,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentActivities() async {
    List<Map<String, dynamic>> activities = [];

    // Get recent payments
    final recentPayments = await _db
        .collection('payments')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get();

    for (final doc in recentPayments.docs) {
      final data = doc.data();
      activities.add({
        'type': 'payment',
        'title': 'New Payment',
        'description':
            'RM ${(data['amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
        'timestamp': data['created_at'],
        'status': data['status'],
      });
    }

    // Get recent service requests
    final recentRequests = await _db
        .collectionGroup('service_requests')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get();

    for (final doc in recentRequests.docs) {
      final data = doc.data();
      activities.add({
        'type': 'request',
        'title': 'Service Request',
        'description': data['student_name'] ?? 'Unknown',
        'timestamp': data['created_at'],
        'status': data['status'],
      });
    }

    // Sort all activities by timestamp
    activities.sort((a, b) {
      final aTime = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTime = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    return activities.take(10).toList();
  }
}

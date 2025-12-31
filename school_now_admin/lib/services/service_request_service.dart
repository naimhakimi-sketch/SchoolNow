import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ServiceRequestService {
  final _db = FirebaseFirestore.instance;

  // Get all service requests across all drivers
  Stream<List<Map<String, dynamic>>> getAllServiceRequests() {
    return _db.collectionGroup('service_requests').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['driver_id'] = doc.reference.parent.parent?.id ?? '';
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getServiceRequestsByStatus(String status) {
    return _db
        .collectionGroup('service_requests')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['driver_id'] = doc.reference.parent.parent?.id ?? '';
            return data;
          }).toList();
        });
  }

  Future<Map<String, int>> getRequestStatistics() async {
    final snapshot = await _db.collectionGroup('service_requests').get();

    int total = snapshot.docs.length;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final doc in snapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
    };
  }

  Future<String> getParentName(String parentId) async {
    if (parentId.isEmpty) return 'Unknown';
    final doc = await _db.collection('parents').doc(parentId).get();
    if (!doc.exists) return 'Unknown';
    return doc.data()?['name'] ?? 'Unknown';
  }

  Future<String> getDriverName(String driverId) async {
    if (driverId.isEmpty) return 'Unknown';
    final doc = await _db.collection('drivers').doc(driverId).get();
    if (!doc.exists) return 'Unknown';
    return doc.data()?['name'] ?? 'Unknown';
  }

  Future<void> updateRequestStatus(
    String driverId,
    String requestId,
    String status,
  ) async {
    final requestRef = _db
        .collection('drivers')
        .doc(driverId)
        .collection('service_requests')
        .doc(requestId);

    try {
      await _db.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        final requestData = requestSnap.data();
        if (requestData == null) return;

        // Only operate on pending requests
        if ((requestData['status'] ?? '').toString() != 'pending') return;

        final studentId = (requestData['student_id'] ?? '').toString();
        if (studentId.isEmpty) return;

        final parentId = (requestData['parent_id'] ?? '').toString();
        final paymentId = (requestData['payment_id'] ?? '').toString();

        final parents = _db.collection('parents');
        final payments = _db.collection('payments');

        // Enforce: 1 student = max 1 driver.
        if (parentId.isNotEmpty) {
          final childRef = parents
              .doc(parentId)
              .collection('children')
              .doc(studentId);
          final childSnap = await tx.get(childRef);
          final child = childSnap.data();
          final assigned = (child?['assigned_driver_id'] ?? '').toString();
          if (assigned.isNotEmpty && assigned != driverId) {
            // Already assigned to someone else. Reject + refund.
            tx.set(requestRef, {
              'status': 'rejected',
              'updated_at': FieldValue.serverTimestamp(),
              'reason': 'already_assigned',
            }, SetOptions(merge: true));
            if (paymentId.isNotEmpty) {
              tx.set(payments.doc(paymentId), {
                'status': 'refunded',
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
            return;
          }

          // Assign child to this driver (merge to avoid overwriting other fields)
          tx.set(childRef, {
            'assigned_driver_id': driverId,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Add student to driver's students collection
        final studentsRef = _db
            .collection('drivers')
            .doc(driverId)
            .collection('students')
            .doc(studentId);
        tx.set(studentsRef, {
          'student_name': requestData['student_name'] ?? '',
          'parent_name': requestData['parent_name'] ?? '',
          'contact_number': requestData['contact_number'] ?? '',
          'parent_id': parentId,
          'pickup_location': requestData['pickup_location'] ?? '',
          'attendance_override': 'attending',
          'attendance_date_ymd': '',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Mark request as approved
        tx.set(requestRef, {
          'status': status,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Complete payment if present
        if (paymentId.isNotEmpty) {
          tx.set(payments.doc(paymentId), {
            'status': 'completed',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error updating request status: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

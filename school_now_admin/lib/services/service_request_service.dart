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
    int renewal = 0;
    int approved = 0;
    int rejected = 0;

    for (final doc in snapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'renewal':
          renewal++;
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
      'renewal': renewal,
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

        // Only operate on pending or renewal requests
        final currentStatus = (requestData['status'] ?? '').toString();
        if (currentStatus != 'pending' && currentStatus != 'renewal') return;

        final studentId = (requestData['student_id'] ?? '').toString();
        if (studentId.isEmpty) return;

        final parentId = (requestData['parent_id'] ?? '').toString();
        final paymentId = (requestData['payment_id'] ?? '').toString();

        final parents = _db.collection('parents');
        final payments = _db.collection('payments');

        if (status == 'approved') {
          // Enforce: 1 student = max 1 driver.
          Map<String, dynamic>? child;
          if (parentId.isNotEmpty) {
            final childRef = parents
                .doc(parentId)
                .collection('children')
                .doc(studentId);
            final childSnap = await tx.get(childRef);
            child = childSnap.data();
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

            // Calculate service end date
            DateTime serviceEndDate;
            if (currentStatus == 'renewal') {
              // For renewal, extend by 1 month from existing end date
              final existingEndDate = (child?['service_end_date'] as Timestamp?)
                  ?.toDate();
              if (existingEndDate != null) {
                // Extend from the existing end date
                serviceEndDate = DateTime(
                  existingEndDate.year + (existingEndDate.month == 12 ? 1 : 0),
                  existingEndDate.month == 12 ? 1 : existingEndDate.month + 1,
                  existingEndDate.day,
                );
              } else {
                // Fallback: extend from today (shouldn't happen for renewal)
                final now = DateTime.now();
                serviceEndDate = DateTime(
                  now.year + (now.month == 12 ? 1 : 0),
                  now.month == 12 ? 1 : now.month + 1,
                  now.day,
                );
              }
            } else {
              // For new requests, set to 1 month from today (1st of next month)
              final now = DateTime.now();
              serviceEndDate = DateTime(
                now.year + (now.month == 12 ? 1 : 0),
                now.month == 12 ? 1 : now.month + 1,
                1,
              );
            }

            // Assign child to this driver (merge to avoid overwriting other fields)
            tx.set(childRef, {
              'assigned_driver_id': driverId,
              'service_end_date': serviceEndDate,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          // Sync to driver's students collection (read-only cache)
          final driverStudentRef = _db
              .collection('drivers')
              .doc(driverId)
              .collection('students')
              .doc(studentId);

          // Get the child data to sync to driver collection
          final childData = child ?? {};

          tx.set(driverStudentRef, {
            'child_id': studentId,
            'parent_id': parentId,
            'child_name': childData['child_name'] ?? '',
            'school_name': childData['school_name'] ?? '',
            'school_id': childData['school_id'] ?? '',
            'pickup_location': requestData['pickup_location'] ?? '',
            'contact_number':
                requestData['parent_phone'] ??
                requestData['contact_number'] ??
                '',
            'attendance_override': 'attending',
            'attendance_date_ymd': '',
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Complete payment if present
          if (paymentId.isNotEmpty) {
            tx.set(payments.doc(paymentId), {
              'status': 'completed',
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } else if (status == 'rejected') {
          // Refund payment if present
          if (paymentId.isNotEmpty) {
            tx.set(payments.doc(paymentId), {
              'status': 'refunded',
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }

        // Mark request as approved or rejected
        tx.set(requestRef, {
          'status': status,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e, stackTrace) {
      debugPrint('Error updating request status: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

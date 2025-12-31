import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StudentManagementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _studentsRef(String driverId) =>
      _db.collection('drivers').doc(driverId).collection('students');

  CollectionReference<Map<String, dynamic>> _requestsRef(String driverId) =>
      _db.collection('drivers').doc(driverId).collection('service_requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamApprovedStudents(
    String driverId,
  ) {
    return _studentsRef(
      driverId,
    ).orderBy('created_at', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingRequests(
    String driverId,
  ) {
    // Avoid composite index requirement (status + created_at).
    // We'll sort client-side in the UI.
    return _requestsRef(
      driverId,
    ).where('status', isEqualTo: 'pending').snapshots();
  }

  Future<List<String>> getApprovedStudentIds(String driverId) async {
    final snap = await _studentsRef(driverId).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<void> approveRequest({
    required String driverId,
    required String requestId,
  }) async {
    final reqDoc = _requestsRef(driverId).doc(requestId);
    final students = _studentsRef(driverId);
    final payments = _db.collection('payments');
    final parents = _db.collection('parents');

    try {
      await _db.runTransaction((tx) async {
        final reqSnap = await tx.get(reqDoc);
        final data = reqSnap.data();
        if (data == null) return;
        if ((data['status'] ?? '').toString() != 'pending') return;

        final studentId = (data['student_id'] ?? '').toString();
        if (studentId.isEmpty) return;

        final parentId = (data['parent_id'] ?? '').toString();
        final paymentId = (data['payment_id'] ?? '').toString();

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
            tx.set(reqDoc, {
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

          tx.set(childRef, {
            'assigned_driver_id': driverId,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        tx.set(students.doc(studentId), {
          'student_name': data['student_name'],
          'parent_name': data['parent_name'],
          'contact_number': data['contact_number'],
          'parent_id': parentId,
          'pickup_location': data['pickup_location'],
          'attendance_override': 'attending',
          'attendance_date_ymd': '',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(reqDoc, {
          'status': 'approved',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (paymentId.isNotEmpty) {
          tx.set(payments.doc(paymentId), {
            'status': 'completed',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e, stackTrace) {
      // Log the error with more details for debugging
      debugPrint('Error approving request: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw to let the UI handle it
      rethrow;
    }
  }

  Future<void> rejectRequest({
    required String driverId,
    required String requestId,
  }) async {
    final reqDoc = _requestsRef(driverId).doc(requestId);
    final payments = _db.collection('payments');

    try {
      await _db.runTransaction((tx) async {
        final reqSnap = await tx.get(reqDoc);
        final data = reqSnap.data();
        if (data == null) return;

        final paymentId = (data['payment_id'] ?? '').toString();

        tx.set(reqDoc, {
          'status': 'rejected',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (paymentId.isNotEmpty) {
          tx.set(payments.doc(paymentId), {
            'status': 'refunded',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e, stackTrace) {
      // Log the error with more details for debugging
      debugPrint('Error rejecting request: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw to let the UI handle it
      rethrow;
    }
  }
}

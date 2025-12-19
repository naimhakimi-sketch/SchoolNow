import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamForUser(String userId) {
    return _notifications.where('user_id', isEqualTo: userId).orderBy('created_at', descending: true).limit(20).snapshots();
  }

  Future<void> markRead(String notificationId) async {
    await _notifications.doc(notificationId).set(
      {
        'read': true,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Creates a notification with a deterministic doc id to avoid duplicates.
  Future<void> createUnique({
    required String notificationId,
    required String userId,
    required String type,
    required String message,
  }) async {
    await _notifications.doc(notificationId).set(
      {
        'user_id': userId,
        'type': type,
        'message': message,
        'read': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

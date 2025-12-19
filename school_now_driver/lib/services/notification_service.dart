import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');

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

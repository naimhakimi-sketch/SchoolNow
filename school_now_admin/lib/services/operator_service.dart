import 'package:cloud_firestore/cloud_firestore.dart';

class OperatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get operator settings
  Future<Map<String, dynamic>?> getOperatorSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('operator').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update operator settings
  Future<void> updateOperatorSettings({
    required String address,
    required double latitude,
    required double longitude,
    String? contactNumber,
    String? contactEmail,
  }) async {
    await _firestore.collection('settings').doc('operator').set({
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_number': contactNumber,
      'contact_email': contactEmail,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Stream operator settings
  Stream<DocumentSnapshot> getOperatorSettingsStream() {
    return _firestore.collection('settings').doc('operator').snapshots();
  }
}

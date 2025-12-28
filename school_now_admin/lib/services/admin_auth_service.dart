import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  final _db = FirebaseFirestore.instance;

  Future<bool> login(String username, String password) async {
    final doc = await _db.collection('admins').doc('main_admin').get();

    if (!doc.exists) return false;

    return doc['username'] == username && doc['password'] == password;
  }

  Future<void> updateCredentials(String newUser, String newPass) async {
    await _db.collection('admins').doc('main_admin').update({
      'username': newUser,
      'password': newPass,
    });
  }
}

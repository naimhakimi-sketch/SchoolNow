import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String normalizeIc(String value) => value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

  Future<UserCredential> registerParent({
    required String icNumber,
    required String name,
    required String email,
    required String contactNumber,
    required String address,
    required String password,
    double? pickupLat,
    double? pickupLng,
  }) async {
    final rawIc = icNumber.trim();
    final normalized = normalizeIc(rawIc);

    final existing = await Future.wait([
      _db.collection('parents').where('ic_number', isEqualTo: rawIc).limit(1).get(),
      _db.collection('parents').where('ic_number_normalized', isEqualTo: normalized).limit(1).get(),
    ]);
    if (existing.any((s) => s.docs.isNotEmpty)) {
      throw FirebaseAuthException(code: 'ic-already-in-use', message: 'This IC number is already registered.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(name);
    final uid = cred.user!.uid;

    final doc = <String, dynamic>{
      'role': 'parent',
      'ic_number': rawIc,
      'ic_number_normalized': normalized,
      'name': name,
      'email': email,
      'contact_number': contactNumber,
      'address': address,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'notifications': {
        'proximity_alert': true,
        'boarding_alert': true,
      },
    };

    if (pickupLat != null && pickupLng != null) {
      doc['pickup_location'] = {'lat': pickupLat, 'lng': pickupLng};
    }

    await _db.collection('parents').doc(uid).set(doc);
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Student-mode sign-in: child IC + parent password.
  /// We look up the parent email by child IC and sign in as the parent.
  Future<UserCredential> signInStudentMode({
    required String childIcNumber,
    required String parentPassword,
  }) async {
    final normalizedChildIc = normalizeIc(childIcNumber.trim());

    // Find a parent who has a child with this IC.
    // We store child docs under parents/<uid>/children with child_ic_normalized.
    final parentsSnap = await _db.collection('parents').limit(50).get();
    for (final p in parentsSnap.docs) {
      final childSnap = await p.reference
          .collection('children')
          .where('child_ic_normalized', isEqualTo: normalizedChildIc)
          .limit(1)
          .get();
      if (childSnap.docs.isEmpty) continue;

      final email = (p.data()['email'] ?? '').toString();
      if (email.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-email', message: 'Parent email is missing.');
      }

      return _auth.signInWithEmailAndPassword(email: email, password: parentPassword);
    }

    throw FirebaseAuthException(
      code: 'child-not-found',
      message: 'No parent/child found for this child IC.',
    );
  }

  Future<void> signOut() => _auth.signOut();
}

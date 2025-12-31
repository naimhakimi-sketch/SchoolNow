import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _normalizeIc(String value) {
    // Be permissive: users often type IC with spaces/dashes.
    // Keep only alphanumerics and uppercase to make matching stable.
    return value.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithIcNumber(
    String icNumber,
    String password,
  ) async {
    final raw = icNumber.trim();
    final normalized = _normalizeIc(raw);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      // Prefer normalized lookup for resilient matching.
      snap = await _db
          .collection('drivers')
          .where('ic_number_normalized', isEqualTo: normalized)
          .limit(1)
          .get();

      // Backward compatibility: older records may not have ic_number_normalized.
      if (snap.docs.isEmpty) {
        snap = await _db
            .collection('drivers')
            .where('ic_number', isEqualTo: raw)
            .limit(1)
            .get();
      }
    } on FirebaseException catch (e) {
      // Common pitfall: Firestore rules often require authentication, but this lookup happens pre-auth.
      if (e.code == 'permission-denied') {
        throw FirebaseAuthException(
          code: 'permission-denied',
          message:
              'Login lookup blocked by Firestore rules. Update Firestore security rules to allow reading drivers by IC for login, or move this lookup server-side.',
        );
      }
      rethrow;
    }

    if (snap.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No driver found for this IC number.',
      );
    }

    final data = snap.docs.first.data();

    // Check if driver is verified
    final isVerified = data['is_verified'] as bool? ?? false;
    if (!isVerified) {
      throw FirebaseAuthException(
        code: 'user-not-verified',
        message:
            'Your account is pending admin verification. Please wait for approval.',
      );
    }

    final email = (data['email'] ?? '').toString();
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Driver profile is missing an email address.',
      );
    }
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail({
    required String icNumber,
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    required String password,
  }) async {
    final rawIc = icNumber.trim();
    final normalizedIc = _normalizeIc(rawIc);

    final existing = await Future.wait([
      _db
          .collection('drivers')
          .where('ic_number', isEqualTo: rawIc)
          .limit(1)
          .get(),
      _db
          .collection('drivers')
          .where('ic_number_normalized', isEqualTo: normalizedIc)
          .limit(1)
          .get(),
    ]);
    if (existing.any((s) => s.docs.isNotEmpty)) {
      throw FirebaseAuthException(
        code: 'ic-already-in-use',
        message: 'This IC number is already registered.',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    final uid = cred.user!.uid;
    final driverDoc = <String, dynamic>{
      'ic_number': rawIc,
      'ic_number_normalized': normalizedIc,
      'name': name,
      'email': email,
      'contact_number': contactNumber,
      'license_number': licenseNumber,
      'role': 'driver',
      'is_verified': false,
      'is_searchable': false,
      'created_at': FieldValue.serverTimestamp(),
    };

    await _db.collection('drivers').doc(uid).set(driverDoc);
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

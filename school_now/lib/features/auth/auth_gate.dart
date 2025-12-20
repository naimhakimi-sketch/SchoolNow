import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = ParentAuthService();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginPage();

        // If Firestore account data was deleted (e.g. parents/<uid> removed),
        // keep the UX consistent by signing out and returning to Login.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('parents')
              .doc(user.uid)
              .snapshots(),
          builder: (context, parentSnap) {
            if (parentSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (parentSnap.hasError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                auth.signOut();
              });
              return const LoginPage();
            }

            final exists = parentSnap.data?.exists ?? false;
            if (!exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                auth.signOut();
              });
              return const LoginPage();
            }

            return HomePage(parentId: user.uid);
          },
        );
      },
    );
  }
}

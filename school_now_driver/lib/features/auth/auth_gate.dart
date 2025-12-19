import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/demo_auth_service.dart';
import '../../services/demo_auth_notifier.dart';
import '../main/main_tabs.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DemoAuthNotifier.enabled,
      builder: (context, isDemoActive, _) {
        if (isDemoActive) {
          return MainTabs(driverId: DemoAuthService.getDemoUid(), isDemoMode: true);
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user != null) {
              return MainTabs(driverId: user.uid, isDemoMode: false);
            }
            return const LoginPage();
          },
        );
      },
    );
  }
}

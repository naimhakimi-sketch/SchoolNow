import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = ParentAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _childIcController = TextEditingController();
  final _studentPasswordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _childIcController.dispose();
    _studentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signInParent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInStudentMode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInStudentMode(
        childIcNumber: _childIcController.text.trim(),
        parentPassword: _studentPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (e) {
      setState(() {
        _error = 'Student login failed!: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [Image.asset('assets/launcher/title.png', height: 36)],
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const SizedBox(height: 16),
          // Logo Section
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/launcher/foreground.png',
                    height: 100,
                    width: 100,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login to your account',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Parent Login Section
          Text(
            'Parent Login',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _signInParent,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black87),
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
          // Student Login Section
          Text(
            'Student Login',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _childIcController,
            decoration: InputDecoration(
              labelText: 'Child IC / Student ID',
              prefixIcon: const Icon(Icons.person_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studentPasswordController,
            decoration: InputDecoration(
              labelText: 'Parent Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              labelStyle: TextStyle(color: Colors.grey[600]),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _loading ? null : _signInStudentMode,
              child: const Text(
                'Login as Student',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
            child: const Text(
              "Don't have an account? Create one",
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

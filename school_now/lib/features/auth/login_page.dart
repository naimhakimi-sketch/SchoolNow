import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SchoolNow')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Parent Login', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _signInParent,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Student Login', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _childIcController,
            decoration: const InputDecoration(labelText: 'Child IC'),
          ),
          TextField(
            controller: _studentPasswordController,
            decoration: const InputDecoration(labelText: 'Parent Password'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : _signInStudentMode,
              child: const Text('Login as Student'),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
            child: const Text('Create Parent Account'),
          ),
        ],
      ),
    );
  }
}

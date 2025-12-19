import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/demo_auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _icController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showDemoMode = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = AuthService();
      await auth.signInWithIcNumber(_icController.text.trim(), _passwordController.text);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _demoLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await DemoAuthService.setupDemoUser();
      // Demo mode is now active—AuthGate will handle the redirect
    } catch (e) {
      setState(() {
        _error = 'Failed to enter demo mode: $e';
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
  void initState() {
    super.initState();
    // Nothing to prefill by default.
  }

  @override
  void dispose() {
    _icController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Login'),
        actions: [
          IconButton(
            icon: Icon(_showDemoMode ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () {
              setState(() {
                _showDemoMode = !_showDemoMode;
              });
            },
            tooltip: 'Toggle Demo Mode',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_showDemoMode)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Demo Mode: Tests Firebase Realtime DB & Firestore integration without reCAPTCHA.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            TextField(
              controller: _icController,
              decoration: const InputDecoration(labelText: 'IC Number'),
              enabled: !_showDemoMode,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              enabled: !_showDemoMode,
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            if (!_showDemoMode)
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator() : const Text('Login'),
              )
            else
              ElevatedButton.icon(
                onPressed: _loading ? null : _demoLogin,
                icon: const Icon(Icons.bug_report),
                label: _loading ? const CircularProgressIndicator() : const Text('Enter Demo Mode'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            const SizedBox(height: 8),
            if (!_showDemoMode)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
                },
                child: const Text('Create account'),
              ),
          ],
        ),
      ),
    );
  }
}

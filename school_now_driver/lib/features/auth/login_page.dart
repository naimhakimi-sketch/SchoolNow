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
      await auth.signInWithIcNumber(
        _icController.text.trim(),
        _passwordController.text,
      );
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
      backgroundColor: const Color(0xFFECCC6E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Image.asset(
                    'launcher/foreground.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Image.asset(
                  'launcher/title.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_showDemoMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demo Mode Active',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // IC Number Field
                TextField(
                  controller: _icController,
                  decoration: InputDecoration(
                    labelText: 'IC Number',
                    prefixIcon: const Icon(Icons.badge),
                    hintText: 'Enter your IC number',
                    enabled: !_showDemoMode,
                  ),
                  enabled: !_showDemoMode,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    hintText: 'Enter your password',
                    enabled: !_showDemoMode,
                  ),
                  obscureText: true,
                  enabled: !_showDemoMode,
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: !_showDemoMode
                      ? ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF814256),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _loading ? null : _demoLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF814256),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.bug_report),
                          label: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Enter Demo Mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                ),
                const SizedBox(height: 16),

                // Create Account Link
                if (!_showDemoMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          color: Color(0xFF2C2C2C),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF814256),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Demo Mode Toggle Button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDemoMode = !_showDemoMode;
                      });
                    },
                    icon: Icon(
                      _showDemoMode
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                      size: 16,
                      color: const Color(0xFF2C2C2C),
                    ),
                    label: Text(
                      _showDemoMode ? 'Exit Demo Mode' : 'Demo Mode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2C2C2C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';

class ChangeCredentialsScreen extends StatefulWidget {
  const ChangeCredentialsScreen({super.key});

  @override
  State<ChangeCredentialsScreen> createState() =>
      _ChangeCredentialsScreenState();
}

class _ChangeCredentialsScreenState extends State<ChangeCredentialsScreen> {
  final newUserCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final service = AdminAuthService();

  bool isSaving = false;

  Future<void> save() async {
    if (newUserCtrl.text.isEmpty || newPassCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    setState(() => isSaving = true);

    await service.updateCredentials(
      newUserCtrl.text.trim(),
      newPassCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() => isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credentials updated successfully')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Change Credentials')),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 56, color: Colors.indigo),
              const SizedBox(height: 12),
              const Text(
                'Update Admin Credentials',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Make sure to remember your new login details',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: newUserCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

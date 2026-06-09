import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/navigation/back_navigation.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class EditInfoScreen extends StatefulWidget {
  const EditInfoScreen({super.key});

  @override
  State<EditInfoScreen> createState() => _EditInfoScreenState();
}

class _EditInfoScreenState extends State<EditInfoScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _usernameController = TextEditingController(text: auth.username);
    _emailController = TextEditingController(text: auth.email);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await context.read<AuthProvider>().updateProfile(
          _usernameController.text.trim(),
          _emailController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      goBackOr(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOr(context, '/profile'),
        ),
        title: const Text('Edit Info', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primary),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

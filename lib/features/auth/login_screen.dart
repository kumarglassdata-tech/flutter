import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String? targetRoute;
  const LoginScreen({super.key, this.targetRoute});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final error =
        await auth.login(_usernameController.text, _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      final dest = widget.targetRoute ?? '/home';
      context.go(dest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F9FF), Color(0xFFE8F4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? size.width * 0.3 : 24,
              vertical: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/smart_myna_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).scale(
                    begin: const Offset(0.8, 0.8), duration: 500.ms),

                const SizedBox(height: 32),

                Text('Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ))
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideX(begin: -0.1),

                const SizedBox(height: 4),

                Text('Sign in to your Smart Myna account',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.onSurfaceVariant))
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: 36),

                // Error banner
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().shakeX(hz: 4, amount: 4),

                // Username field
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    prefixIcon:
                        Icon(Icons.person_outline_rounded, color: AppTheme.primary),
                  ),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => _errorMessage = null),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                  onChanged: (_) => setState(() => _errorMessage = null),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms)
                    .slideY(begin: 0.2),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 8),

                const SizedBox(height: 8),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 400.ms),

                const SizedBox(height: 28),

                Center(
                  child: Text('or continue with',
                      style: TextStyle(color: Colors.grey[500])),
                ),

                const SizedBox(height: 16),

                // Social buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(Icons.account_box_rounded, 'Google'),
                    const SizedBox(width: 16),
                    _socialButton(Icons.face_rounded, 'Apple'),
                  ],
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                const SizedBox(height: 32),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(color: Colors.grey[600])),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Sign up',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Icon(icon, size: 24, color: AppTheme.onSurface),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        context.go(auth.isLoggedIn ? '/home' : '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/smart_myna_logo.png',
                  fit: BoxFit.cover,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.6, 0.6), duration: 700.ms,
                      curve: Curves.easeOutBack),

              const SizedBox(height: 28),

              Text(
                'Smart Myna',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.3, duration: 500.ms),

              const SizedBox(height: 8),

              Text(
                'AI-Powered Ecommerce Platform',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms),

              const SizedBox(height: 80),

              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              )
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 500.ms),

              const SizedBox(height: 16),

              Text(
                'Loading…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              )
                  .animate()
                  .fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}

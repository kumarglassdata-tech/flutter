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
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // Warm, earthy blurred gradient background
          gradient: LinearGradient(
            colors: [
              Color(0xFF38402D), // Deep moss green
              Color(0xFF4C3E27), // Warm earthy brown
              Color(0xFF282D20), // Darker green/black
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.1, 0.5, 0.9],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              
              // Animated Circular Logo with Gold Halo
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border.all(
                    color: const Color(0xFFE5C885), // Soft gold
                    width: 4.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE5C885).withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/smart_myna_logo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 400.ms,
                      curve: Curves.easeOutCubic),

              const SizedBox(height: 40),

              // "MYNA" Elegant Typography
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF7E6B4), Color(0xFFD4AF37), Color(0xFFB48C2B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Text(
                  'MYNA',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: Colors.white, // Masked by shader
                    fontSize: 54,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 6.0,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut),

              const SizedBox(height: 16),

              // Subtitle 1
              const Text(
                'Connect. See. Interact. Discover. Buy.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms),

              const SizedBox(height: 6),

              // Subtitle 2
              Text(
                'AI-Powered Smart Glasses',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.3,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 300.ms),

              const Spacer(flex: 4),

              // Loading Text
              Text(
                'App Loading...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 200.ms),

              const SizedBox(height: 12),

              // Sleek Linear Progress Bar
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 200.ms),

              const SizedBox(height: 48), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}


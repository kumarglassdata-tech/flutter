import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. (Env and Wakelock are now loaded in main.dart)

    // 2. Load providers synchronously via context
    if (mounted) {
      final auth = context.read<AuthProvider>();
      final settings = context.read<SettingsProvider>();
      await auth.load();
      await settings.load();
    }

    // 3. Just enough delay to let the fade-in animation play (400ms)
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Just plain black
      body: Container(
        width: double.infinity,
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric Water Ripples Background
              _buildWaterRipple(300, 2500, 0),
              _buildWaterRipple(220, 2500, 600),
              _buildWaterRipple(140, 2500, 1200),

              Column(
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
                          color:
                              const Color(0xFFE5C885).withValues(alpha: 0.25),
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
                  ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 400.ms,
                      curve: Curves.easeOutCubic),

                  const SizedBox(height: 40),

                  // "MYNA" Elegant Typography
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFF7E6B4),
                        Color(0xFFD4AF37),
                        Color(0xFFB48C2B)
                      ],
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
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(
                      begin: 0.2, duration: 400.ms, curve: Curves.easeOut),

                  const Spacer(flex: 4),

                  // Sleek Linear Progress Bar
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 200.ms),

                  const SizedBox(height: 48),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterRipple(double size, int durationMs, int delayMs) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: const Color(0xFFE5C885).withValues(alpha: 0.15), width: 1.5),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(3.0, 3.0),
            duration: durationMs.ms,
            delay: delayMs.ms)
        .fade(begin: 1, end: 0, duration: durationMs.ms, delay: delayMs.ms);
  }
}

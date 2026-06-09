import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartglass_flutter/core/navigation/back_navigation.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOr(context, '/home'),
        ),
        title: const Text('About Smart Myna',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
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
              ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.7, 0.7), duration: 600.ms,
                  curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              Text(
                'Smart Myna Platform',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              Text(
                'Version 1.0.0-PROTOTYPE',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppTheme.onSurfaceVariant),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              Text(
                'This application is a complete cross-platform ecosystem for AI-powered smart glasses, integrating persistent hardware runtimes with real-time on-device inference. Built with Flutter for Android, iOS, and Web.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppTheme.onSurfaceVariant, height: 1.6),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 40),

              // Feature badges
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _Badge(Icons.android_rounded, 'Android', Color(0xFF22C55E)),
                  _Badge(Icons.phone_iphone_rounded, 'iOS', Color(0xFF6366F1)),
                  _Badge(Icons.language_rounded, 'Web', Color(0xFF3B82F6)),
                  _Badge(Icons.psychology_rounded, 'AI Engine', Color(0xFFF59E0B)),
                  _Badge(Icons.bluetooth_rounded, 'BLE', Color(0xFF06B6D4)),
                ],
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 40),

              Text(
                '© 2026 GlassData.ai · All rights reserved',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

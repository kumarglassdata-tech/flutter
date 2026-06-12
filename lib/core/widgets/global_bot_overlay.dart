import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class GlobalBotOverlay extends StatefulWidget {
  const GlobalBotOverlay({super.key});

  @override
  State<GlobalBotOverlay> createState() => _GlobalBotOverlayState();
}

class _GlobalBotOverlayState extends State<GlobalBotOverlay> {
  bool _isInteracting = false;

  void _onTap() {
    setState(() {
      _isInteracting = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Interacting subsystem wants to work...',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isInteracting = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _isInteracting ? AppTheme.primary.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.2),
                blurRadius: _isInteracting ? 20 : 10,
                spreadRadius: _isInteracting ? 5 : 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/bot.png',
            fit: BoxFit.contain,
          ),
        ).animate(target: _isInteracting ? 1 : 0)
         .scaleXY(end: 1.1, duration: 200.ms, curve: Curves.easeOut)
         .shimmer(duration: 1.seconds, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}

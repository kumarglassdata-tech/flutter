import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class SessionOverviewCard extends StatelessWidget {
  final SessionState state;
  const SessionOverviewCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (state.isDegraded) {
      bg = Theme.of(context).colorScheme.errorContainer;
      iconColor = Theme.of(context).colorScheme.error;
      icon = Icons.warning_rounded;
      title = 'Session Degraded';
      subtitle = 'Check engine status below';
    } else if (state.isSessionActive) {
      bg = Theme.of(context).colorScheme.primaryContainer;
      iconColor = AppTheme.primary;
      icon = Icons.check_circle_rounded;
      title = 'Session Active';
      subtitle = 'Runtime is orchestrating hardware';
    } else {
      bg = Theme.of(context).colorScheme.surfaceContainerHighest;
      iconColor = AppTheme.onSurfaceVariant;
      icon = Icons.info_outline_rounded;
      title = 'Session Idle';
      subtitle = 'Ready to start runtime';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
          if (state.isSessionActive) ...[
            const Spacer(),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 800.ms,
                  curve: Curves.easeInOut,
                ),
          ],
        ],
      ),
    );
  }
}

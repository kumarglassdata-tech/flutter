import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class EngineCard extends StatelessWidget {
  final String title;
  final EngineState engineState;
  final IconData icon;
  final List<(String, String)> metrics;

  const EngineCard({
    super.key,
    required this.title,
    required this.engineState,
    required this.icon,
    required this.metrics,
  });

  Color _stateColor() {
    switch (engineState) {
      case EngineState.idle:
        return Colors.grey;
      case EngineState.starting:
        return const Color(0xFF06B6D4);
      case EngineState.running:
        return const Color(0xFF22C55E);
      case EngineState.stopping:
        return const Color(0xFFF59E0B);
      case EngineState.failed:
        return const Color(0xFFEF4444);
    }
  }

  String _stateLabel() => engineState.name.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stateColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _stateLabel(),
                    style: TextStyle(
                      color: _stateColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: metrics
                  .map((m) => Column(
                        children: [
                          Text(
                            m.$2,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          Text(
                            m.$1,
                            style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

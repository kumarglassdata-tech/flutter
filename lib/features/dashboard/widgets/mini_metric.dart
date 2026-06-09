import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const MiniMetric({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

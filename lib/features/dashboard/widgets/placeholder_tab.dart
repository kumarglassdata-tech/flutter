import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  const PlaceholderTab({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 64,
            color: AppTheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '$title View',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class AiResultCard extends StatelessWidget {
  final AIResult result;
  const AiResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Inference',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  result.label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  '${(result.confidence * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: result.confidence,
                backgroundColor: AppTheme.outline,
                color: AppTheme.primary,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';

class SourceInputSelector extends StatelessWidget {
  const SourceInputSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final activeType = session.sourceManager.activeType;

    final sources = [
      (SourceType.phone, 'Phone Camera', Icons.phone_android_rounded),
      (SourceType.meta, 'Meta Glasses', Icons.remove_red_eye_rounded),
      (SourceType.videoUpload, 'File Ingestion', Icons.cloud_upload_rounded),
      (SourceType.mock, 'Simulated Ingest', Icons.auto_awesome_rounded),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_input_component_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ingestion Source',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sources.map((src) {
                  final type = src.$1;
                  final label = src.$2;
                  final icon = src.$3;
                  final isSelected = activeType == type;
                  final colorScheme = Theme.of(context).colorScheme;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      iconTheme: IconThemeData(
                        color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16),
                          const SizedBox(width: 6),
                          Text(label),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) async {
                        if (type == SourceType.meta) {
                          await session.connectToMetaGlasses();
                        } else {
                          await session.sourceManager.switchSource(type);
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                      ),
                      selectedColor: colorScheme.primary,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

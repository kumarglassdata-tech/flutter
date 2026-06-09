import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final bool isActive;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ControlPanel({
    super.key,
    required this.isActive,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isActive
          ? ElevatedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text(
                'Stop Runtime',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            )
          : ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Start Runtime',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

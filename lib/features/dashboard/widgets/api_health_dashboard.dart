import 'package:flutter/material.dart';
import '../models/engine_context.dart';

class ApiHealthDashboard extends StatelessWidget {
  final List<EngineTelemetry> telemetryList;

  const ApiHealthDashboard({Key? key, required this.telemetryList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'API Health Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (telemetryList.isEmpty)
            const Text('No telemetry data yet.', style: TextStyle(color: Colors.grey)),
          ...telemetryList.map((t) {
            final statusColor = t.success ? Colors.green : Colors.red;
            final statusText = t.success ? 'Healthy' : 'Timeout/Error';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${t.engine}:', style: const TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text('${t.latencyMs}ms', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/models/engine_status.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class PipelineVisualizer extends StatelessWidget {
  const PipelineVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionProvider>().state;
    final statuses = state.engineStatuses;
    
    // Ordered pipeline steps
    final steps = [
      'ContextEngine',
      'BehaviorEngine',
      'GateCheck',
      'InteractionEngine',
      'EcomEngine',
      'SafetyMemory',
    ];

    bool hasError = false;
    bool hasGated = false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Pipeline Execution Track',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ...steps.map((engineName) {
              final status = statuses[engineName];

              // Determine visual state
              bool isError = status?.state == 'ERROR';
              bool isSkipped = false;
              bool isConnected = status?.state == 'CONNECTED';

              if (isError) hasError = true;
              
              // We check if the GateCheck message says CLOSED. Wait, GateCheck might not have a message if it's connected and open.
              // If it's connected but closed, we need to check SessionState or we can rely on Interaction/Ecom being skipped.
              if (engineName == 'GateCheck' && status?.message != null && status!.message!.contains('CLOSED')) {
                hasGated = true;
              }

              // In pipeline_coordinator.dart, if gateOpen = false, it sets sharedState['pipeline.status'] = 'GATED'.
              // It doesn't put "CLOSED" in the message. Actually, wait. It says: 
              // `Gate status: CLOSED (${gateRes.errorMessage})` in print, but gateRes.isSuccess is true if it successfully evaluated.
              // Let's assume if it's not connected, it's skipped. 
              
              if (hasError && status == null && engineName != 'SafetyMemory') {
                isSkipped = true;
              }
              // If we see Interaction and Ecom are null but we passed Behavior without error, it's gated or we are just waiting.
              // To be safe, if we have a GateCheck status and we are looking at Interaction/Ecom and they are null while SafetyMemory is present, we know it was gated!
              if (engineName == 'InteractionEngine' || engineName == 'EcomEngine') {
                 if (statuses['GateCheck']?.state == 'CONNECTED' && statuses['SafetyMemory'] != null && status == null) {
                   isSkipped = true;
                 }
              }

              if (status == null && !isSkipped) {
                return _buildStep(
                  context,
                  title: _formatEngineName(engineName),
                  icon: Icons.circle_outlined,
                  color: Colors.grey.withOpacity(0.5),
                  subtitle: 'Pending...',
                );
              }

              if (isSkipped) {
                return _buildStep(
                  context,
                  title: _formatEngineName(engineName),
                  icon: Icons.remove_circle_outline,
                  color: Colors.grey,
                  subtitle: 'Skipped',
                );
              }

              if (isError) {
                return _buildStep(
                  context,
                  title: _formatEngineName(engineName),
                  icon: Icons.error_outline,
                  color: AppTheme.error,
                  subtitle: 'Failed (${status?.latency?.inMilliseconds ?? 0}ms)\n${status?.message ?? "Unknown error"}',
                  isError: true,
                ).animate().shake(duration: 400.ms, hz: 3);
              }

              if (isConnected) {
                return _buildStep(
                  context,
                  title: _formatEngineName(engineName),
                  icon: Icons.check_circle_outline,
                  color: AppTheme.success,
                  subtitle: 'Completed (${status?.latency?.inMilliseconds ?? 0}ms)',
                ).animate().fadeIn(duration: 300.ms);
              }

              return _buildStep(
                context,
                title: _formatEngineName(engineName),
                icon: Icons.hourglass_empty,
                color: AppTheme.warning,
                subtitle: 'Connecting...',
              );
            }),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  String _formatEngineName(String name) {
    if (name == 'ContextEngine') return 'Context Engine';
    if (name == 'BehaviorEngine') return 'Behavior Engine';
    if (name == 'GateCheck') return 'Gate Check';
    if (name == 'InteractionEngine') return 'Interaction Engine';
    if (name == 'EcomEngine') return 'Ecom Engine';
    if (name == 'SafetyMemory') return 'Safety Memory';
    return name;
  }

  Widget _buildStep(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isError ? AppTheme.error : AppTheme.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isError ? AppTheme.error.withOpacity(0.8) : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

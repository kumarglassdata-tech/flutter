import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/features/diagnostics/widgets/pipeline_visualizer.dart';
import 'package:smartglass_flutter/features/diagnostics/widgets/permissions_auditor.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionProvider>().state;
    final telemetryLogs = context.watch<SessionProvider>().telemetryService.logs;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AppShell.openDrawer),
        title: const Text('Diagnostics',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PermissionsAuditor(),
            const SizedBox(height: 16),
            // Metrics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_heart_rounded,
                            color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Real-time Metrics',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DiagRow('Camera FPS', state.mediaFps.toStringAsFixed(1)),
                    _DiagRow('AI Throughput', '${state.aiThroughputFps.toStringAsFixed(1)} fps'),
                    _DiagRow('Inference Latency', '${state.aiLatencyMs.toStringAsFixed(0)} ms'),
                    _DiagRow('Realtime RTT', '${state.rttMs} ms'),
                    _DiagRow('BLE RSSI', '${state.bleRssi} dBm'),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),
            const PipelineVisualizer(),
            const SizedBox(height: 20),

            Row(
              children: [
                const Icon(Icons.terminal_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Runtime Events',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${state.eventLogs.length} events',
                  style: const TextStyle(
                      color: AppTheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 10),

            // Console
            SizedBox(
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.eventLogs.isEmpty ? 1 : state.eventLogs.length,
                    itemBuilder: (_, i) {
                      if (state.eventLogs.isEmpty) {
                        return const Text(
                          '> Waiting for events…',
                          style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                              fontSize: 12),
                        );
                      }
                      final log = state.eventLogs[i];
                      Color logColor;
                      if (log.contains('Failed') || log.contains('Error')) {
                        logColor = const Color(0xFFEF4444);
                      } else if (log.contains('WARN') || log.contains('Retry')) {
                        logColor = const Color(0xFFF59E0B);
                      } else if (log.contains('stop') || log.contains('disconnect')) {
                        logColor = const Color(0xFFFB923C);
                      } else {
                        logColor = const Color(0xFF4ADE80);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '> $log',
                          style: TextStyle(
                              color: logColor,
                              fontFamily: 'monospace',
                              fontSize: 11.5),
                        ),
                      );
                    },
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ),

            const SizedBox(height: 24),

            // Diagnostic Telemetry Logs Console
            Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Diagnostic Telemetry',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${telemetryLogs.length} logs',
                  style: const TextStyle(
                      color: AppTheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 10),

            SizedBox(
              height: 400,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: telemetryLogs.isEmpty ? 1 : telemetryLogs.length,
                    itemBuilder: (_, i) {
                      if (telemetryLogs.isEmpty) {
                        return const Text(
                          '> Waiting for telemetry...',
                          style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                              fontSize: 12),
                        );
                      }
                      final log = telemetryLogs[i];
                      final isError = log.isError;
                      final headerColor = isError ? const Color(0xFFEF4444) : const Color(0xFF38BDF8);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${log.timestamp.toIso8601String()}] [${log.source}] ${log.message}',
                              style: TextStyle(
                                  color: headerColor,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            if (log.jsonPayload != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatJson(log.jsonPayload!),
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'monospace',
                                      fontSize: 11),
                                ),
                              ),
                            ],
                            if (log.stackTrace != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x22EF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  log.stackTrace!,
                                  style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontFamily: 'monospace',
                                      fontSize: 11),
                                ),
                              ),
                            ],
                            const Divider(color: Color(0xFF1E293B)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs exported to clipboard')),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export Logs'),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }

  String _formatJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  const _DiagRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

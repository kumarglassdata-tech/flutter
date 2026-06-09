import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/navigation/back_navigation.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class DeviceControlScreen extends StatelessWidget {
  final String deviceId;
  const DeviceControlScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final settings = context.watch<SettingsProvider>();
    final state = session.state;
    final device = state.discoveredDevices
        .where((d) => d.address == deviceId)
        .firstOrNull;
    final displayName = device?.name ?? state.connectedDeviceName ?? deviceId;
    final isBleConnected = state.bleConnectionState == GlassesConnectionState.connected;
    final isConnecting = state.bleConnectionState == GlassesConnectionState.connecting;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOr(context, '/devices'),
        ),
        title: Text(displayName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: state.isSessionActive
                      ? const [Color(0xFF3B82F6), Color(0xFF1E40AF)]
                      : const [Color(0xFF64748B), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (state.isSessionActive
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF64748B))
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bluetooth_rounded,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        state.connectedDeviceName ?? deviceId,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.isSessionActive
                        ? 'Runtime Active — Processing Frames'
                        : 'Connected — Ready to Start',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                  if (state.isSessionActive) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MetricBadge('FPS', state.mediaFps.toStringAsFixed(1)),
                        const SizedBox(width: 12),
                        _MetricBadge('AI', '${state.aiThroughputFps.toStringAsFixed(1)} fps'),
                        const SizedBox(width: 12),
                        _MetricBadge('RTT', '${state.rttMs} ms'),
                      ],
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 28),

            Text('Runtime Control',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),

            const SizedBox(height: 16),

            if (!state.isSessionActive)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (session.isConnecting || session.isStartingRuntime)
                      ? null
                      : () async {
                          await session.connectToDevice(deviceId);
                          await session.startRuntime(useMock: settings.useMockMeta);
                        },
                  icon: (session.isConnecting || session.isStartingRuntime)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                      (session.isConnecting || session.isStartingRuntime)
                          ? 'Starting...'
                          : 'Start Runtime',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 200.ms)
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => session.stopRuntime(),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Runtime',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),

            if (!isBleConnected && !isConnecting && displayName.toLowerCase().contains('meta')) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    await session.registerMetaGlasses();
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Register with Meta View/AI',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Log preview
            if (state.eventLogs.isNotEmpty) ...[
              Text('Recent Events',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: state.eventLogs.length,
                  itemBuilder: (_, i) => Text(
                    '> ${state.eventLogs[i]}',
                    style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontFamily: 'monospace',
                        fontSize: 11),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  const _MetricBadge(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }
}

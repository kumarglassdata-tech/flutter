import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class DeviceControlScreen extends StatefulWidget {
  final String deviceId;
  const DeviceControlScreen({super.key, required this.deviceId});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  double _pendingVolume = 0.5;
  bool _volumeInitialized = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final state = session.state;
    final device = state.discoveredDevices
        .where((d) => d.address == widget.deviceId)
        .firstOrNull;
    final displayName = device?.name ?? state.connectedDeviceName ?? widget.deviceId;
    final isBleConnected = state.bleConnectionState == GlassesConnectionState.connected;
    final isConnecting = state.bleConnectionState == GlassesConnectionState.connecting;

    // Sync volume slider with state once connected
    if (isBleConnected && !_volumeInitialized) {
      _pendingVolume = state.volumeLevel;
      _volumeInitialized = true;
    }
    if (!isBleConnected) _volumeInitialized = false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/devices');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBleConnected
                    ? const Color(0xFF4ADE80)
                    : isConnecting
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF64748B),
              ),
            )
                .animate(
                  onPlay: (c) => isBleConnected || isConnecting
                      ? c.repeat(reverse: true)
                      : null,
                )
                .fade(begin: 1, end: 0.2, duration: 900.ms),
            const SizedBox(width: 10),
            Text(displayName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (isBleConnected)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text(
                  state.isWearing ? 'Worn' : 'Off',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                avatar: Icon(
                  state.isWearing ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                  size: 14,
                ),
                backgroundColor: state.isWearing
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                    : AppTheme.surfaceVariant,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Hero Status Card ───────────────────────────────────────────
            _HeroStatusCard(
              displayName: displayName,
              state: state,
              isBleConnected: isBleConnected,
              isConnecting: isConnecting,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            // ─── Connect / Disconnect Button ────────────────────────────────
            if (!isBleConnected && !isConnecting)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => session.connectToDevice(widget.deviceId),
                  icon: const Icon(Icons.bluetooth_rounded),
                  label: const Text('Connect to Glass',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 100.ms),

            if (isConnecting)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.surfaceVariant,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Text('Connecting...', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ).animate().fadeIn(),

            // ─── Connected Panel ─────────────────────────────────────────────
            if (isBleConnected) ...[
              // Runtime Control
              Row(
                children: [
                  Expanded(
                    child: state.isSessionActive
                        ? _ActionButton(
                            icon: Icons.stop_rounded,
                            label: 'Stop AI Runtime',
                            color: const Color(0xFFDC2626),
                            onTap: () => session.stopRuntime(),
                          )
                        : _ActionButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Start AI Runtime',
                            color: const Color(0xFF3B82F6),
                            onTap: session.isStartingRuntime
                                ? null
                                : () => session.startRuntime(),
                          ),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 20),

              // ─── Volume Control ─────────────────────────────────────────
              _SectionCard(
                title: 'Volume Control',
                icon: Icons.volume_up_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                        Expanded(
                          child: Slider(
                            value: _pendingVolume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            activeColor: AppTheme.primary,
                            onChanged: (v) => setState(() => _pendingVolume = v),
                            onChangeEnd: (v) => session.setVolume(v),
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    Text(
                      '${(_pendingVolume * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 16),

              // ─── Camera & Media Actions ─────────────────────────────────
              _SectionLabel('Camera & Media'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  _GridActionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Capture Photo',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => session.capturePhoto(),
                  ),
                  _GridActionTile(
                    icon: state.isVideoRecording
                        ? Icons.stop_circle_rounded
                        : Icons.videocam_rounded,
                    label: state.isVideoRecording ? 'Stop Video' : 'Start Video',
                    color: state.isVideoRecording
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFEF4444),
                    onTap: () => state.isVideoRecording
                        ? session.stopVideoRecording()
                        : session.startVideoRecording(),
                  ),
                  _GridActionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Import Album',
                    color: const Color(0xFF0891B2),
                    onTap: () => session.importAlbums(),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              // ─── Video Download Progress ─────────────────────────────────
              if (state.videoDownloadProgress > 0.0 && state.videoDownloadProgress < 1.0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Downloading Video...',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8))),
                          Text(
                            '${(state.videoDownloadProgress * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.videoDownloadProgress,
                          minHeight: 6,
                          backgroundColor: AppTheme.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              const SizedBox(height: 16),

              // ─── Device Actions ──────────────────────────────────────────
              _SectionLabel('Device Actions'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Sync Battery',
                      color: const Color(0xFF10B981),
                      onTap: () => session.syncBattery(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.bluetooth_disabled_rounded,
                      label: 'Disconnect',
                      color: const Color(0xFF64748B),
                      onTap: () {
                        session.stopRuntime();
                        context.go('/devices');
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 250.ms),

              const SizedBox(height: 20),

              // ─── Live Metrics ────────────────────────────────────────────
              if (state.isSessionActive)
                _SectionCard(
                  title: 'Live Metrics',
                  icon: Icons.monitor_heart_rounded,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetricPill('FPS', state.mediaFps.toStringAsFixed(1), const Color(0xFF3B82F6)),
                      _MetricPill('AI FPS', state.aiThroughputFps.toStringAsFixed(1), const Color(0xFF8B5CF6)),
                      _MetricPill('RTT', '${state.rttMs}ms', const Color(0xFF10B981)),
                      _MetricPill('RSSI', '${state.bleRssi}dB', const Color(0xFFF59E0B)),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

              if (state.isSessionActive) const SizedBox(height: 16),
            ],

            // ─── Event Log ───────────────────────────────────────────────────
            if (state.eventLogs.isNotEmpty) ...[
              _SectionLabel('Event Log'),
              const SizedBox(height: 8),
              Container(
                height: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: ListView.builder(
                  reverse: true,
                  itemCount: state.eventLogs.length,
                  itemBuilder: (_, i) {
                    final log = state.eventLogs[state.eventLogs.length - 1 - i];
                    return Text(
                      '> $log',
                      style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontFamily: 'monospace',
                          fontSize: 11),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Hero Status Card ─────────────────────────────────────────────────────────
class _HeroStatusCard extends StatelessWidget {
  final String displayName;
  final SessionState state;
  final bool isBleConnected;
  final bool isConnecting;

  const _HeroStatusCard({
    required this.displayName,
    required this.state,
    required this.isBleConnected,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    final Color gradStart = isBleConnected
        ? const Color(0xFF1D4ED8)
        : isConnecting
            ? const Color(0xFFB45309)
            : const Color(0xFF334155);
    final Color gradEnd = isBleConnected
        ? const Color(0xFF0F172A)
        : isConnecting
            ? const Color(0xFF1C1917)
            : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradStart, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradStart.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device name + connection label row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBleConnected
                      ? Icons.bluetooth_connected_rounded
                      : isConnecting
                          ? Icons.bluetooth_searching_rounded
                          : Icons.bluetooth_disabled_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isBleConnected
                          ? (state.isSessionActive
                              ? 'Runtime Active — AI Processing'
                              : 'Connected — Ready')
                          : isConnecting
                              ? 'Establishing connection...'
                              : 'Tap Connect to pair',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isBleConnected) ...[
            const SizedBox(height: 18),
            // Battery + status pills
            Row(
              children: [
                _StatusPill(
                  icon: _batteryIcon(state.batteryLevel),
                  label: state.batteryLevel == 0
                      ? 'Battery N/A'
                      : '${state.batteryLevel}%',
                  color: _batteryColor(state.batteryLevel),
                ),
                const SizedBox(width: 10),
                if (state.isWearing)
                  const _StatusPill(
                    icon: Icons.face_rounded,
                    label: 'Worn',
                    color: Color(0xFF4ADE80),
                  ),
                const SizedBox(width: 10),
                if (state.isVideoRecording)
                  const _StatusPill(
                    icon: Icons.fiber_manual_record,
                    label: 'REC',
                    color: Color(0xFFEF4444),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _batteryIcon(int level) {
    if (level >= 80) return Icons.battery_full_rounded;
    if (level >= 50) return Icons.battery_4_bar_rounded;
    if (level >= 20) return Icons.battery_2_bar_rounded;
    if (level > 0) return Icons.battery_alert_rounded;
    return Icons.battery_unknown_rounded;
  }

  Color _batteryColor(int level) {
    if (level >= 60) return const Color(0xFF4ADE80);
    if (level >= 25) return const Color(0xFFFBBF24);
    if (level > 0) return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }
}

// ── Reusable Widgets ─────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GridActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

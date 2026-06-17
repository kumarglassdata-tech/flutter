import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class PermissionsAuditor extends StatefulWidget {
  const PermissionsAuditor({super.key});

  @override
  State<PermissionsAuditor> createState() => _PermissionsAuditorState();
}

class _PermissionsAuditorState extends State<PermissionsAuditor> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _bluetoothStatus = PermissionStatus.denied;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // Poll every 2 seconds to keep the UI perfectly synced if the user changes settings
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkPermissions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final bt = await Permission.bluetoothConnect.status;

    if (mounted) {
      setState(() {
        _cameraStatus = cam;
        _microphoneStatus = mic;
        _bluetoothStatus = bt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool anyDenied = !_cameraStatus.isGranted || !_microphoneStatus.isGranted || !_bluetoothStatus.isGranted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  anyDenied ? Icons.gpp_maybe_rounded : Icons.gpp_good_rounded,
                  color: anyDenied ? AppTheme.error : AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('System Health & Permissions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (anyDenied)
                  TextButton(
                    onPressed: openAppSettings,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Fix Settings', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              title: 'Microphone',
              icon: Icons.mic_rounded,
              status: _microphoneStatus,
            ),
            _PermissionRow(
              title: 'Camera',
              icon: Icons.camera_alt_rounded,
              status: _cameraStatus,
            ),
            _PermissionRow(
              title: 'Bluetooth',
              icon: Icons.bluetooth_rounded,
              status: _bluetoothStatus,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _PermissionRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final PermissionStatus status;

  const _PermissionRow({
    required this.title,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status.isGranted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (isGranted)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                const SizedBox(width: 4),
                Text('Granted', style: TextStyle(color: AppTheme.success.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 16),
                const SizedBox(width: 4),
                Text('Denied', style: TextStyle(color: AppTheme.error.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}

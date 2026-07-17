import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  double _volumeLevel = 0.5; // UI volume state

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final state = session.state;
    final isConnected = state.bleConnectionState == GlassesConnectionState.connected;
    final isConnecting = state.bleConnectionState == GlassesConnectionState.connecting;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep dark slate
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: AppShell.openDrawer,
        ),
        title: const Text(
          'Connected Devices',
          style: TextStyle(
            fontWeight: FontWeight.w700, 
            color: Colors.white,
            letterSpacing: 1.2
          )
        ),
      ),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.greenAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: isConnecting 
                ? _buildConnectingState(state)
                : (isConnected 
                    ? _buildConnectedDashboard(session, state)
                    : _buildNoDeviceState(session)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingState(SessionState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 24),
          Text(
            "Connecting to \${state.connectedDeviceName ?? 'Glasses'}...",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ).animate().fade(duration: 400.ms),
    );
  }

  Widget _buildNoDeviceState(SessionProvider session) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled_rounded, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No devices are actively connected.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (session.state.eventLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Debug Info: ${session.state.eventLogs.last}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/devices'), 
            icon: const Icon(Icons.search),
            label: const Text('Find Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ).animate().fade(duration: 800.ms),
    );
  }

  Widget _buildConnectedDashboard(SessionProvider session, SessionState state) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildGlassmorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bluetooth_connected, color: Colors.greenAccent, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.connectedDeviceName ?? 'Titan Smart Glasses',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: Active',
                            style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.start,
                  children: [
                    _buildStatusBadge(
                      state.batteryLevel > 20 ? Icons.battery_std : Icons.battery_alert, 
                      '${state.batteryLevel}% Battery',
                      color: state.batteryLevel > 20 ? Colors.greenAccent : Colors.redAccent,
                    ),
                    _buildStatusBadge(Icons.face, 'Worn', color: Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Controls Section
                const Text(
                  'CONTROLS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Volume Slider
                Row(
                  children: [
                    const Icon(Icons.volume_down, color: Colors.white70),
                    Expanded(
                        child: Slider(
                          value: _volumeLevel,
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setState(() {
                              _volumeLevel = val;
                            });
                          },
                          onChangeEnd: (val) {
                            session.hardwareService.setVolume(val);
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Import Album',
                        color: Colors.purpleAccent,
                        onTap: () {
                          session.importAlbums();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Importing gallery...'))
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.power_settings_new_rounded,
                        label: 'Disconnect',
                        color: Colors.redAccent,
                        onTap: () => session.stopRuntime(),
                      ),
                    ),
                  ],
                ),
                if (state.importedAlbums.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'IMPORTED ALBUMS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.importedAlbums.length,
                      itemBuilder: (context, index) {
                        final path = state.importedAlbums[index];
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.video_file, color: Colors.blueAccent, size: 32),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  path.split('/').last,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ).animate().slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutQuad).fade(),
      ],
    );
  }

  Widget _buildStatusBadge(IconData icon, String text, {Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

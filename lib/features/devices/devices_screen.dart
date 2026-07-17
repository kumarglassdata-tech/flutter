import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final state = session.state;
    final isScanning =
        state.bleConnectionState == GlassesConnectionState.scanning;

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
        title: const Text('Pair Devices',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: Icon(
              isScanning ? Icons.stop_circle_outlined : Icons.radar_rounded,
              color: isScanning ? Colors.blueAccent : Colors.white,
            ),
            onPressed: () {
              if (isScanning) {
                session.stopDiscovery();
              } else {
                session.startDiscovery();
              }
            },
          ),
        ],
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
                  colors: [
                    Colors.blueAccent.withOpacity(0.15),
                    Colors.transparent
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scanning Status Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isScanning ? Colors.blueAccent : Colors.grey,
                        ),
                      )
                          .animate(target: isScanning ? 1 : 0)
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.5, 1.5))
                          .fade(begin: 1, end: 0.5)
                          .then(delay: 500.ms),
                      const SizedBox(width: 12),
                      Text(
                        isScanning
                            ? 'Scanning for Titan Glasses...'
                            : 'Scanner Paused',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Device List or Ripple
                Expanded(
                  child: state.discoveredDevices.isEmpty && isScanning
                      ? _buildScanningRipple()
                      : (state.discoveredDevices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bluetooth_disabled,
                                      size: 64,
                                      color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No devices found. Tap scan to search.",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5)),
                                  )
                                ],
                              ).animate().fade(duration: 800.ms),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: state.discoveredDevices.length,
                              itemBuilder: (context, index) {
                                final device = state.discoveredDevices[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildGlassmorphicCard(
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.bluetooth,
                                            color: Colors.white),
                                      ),
                                      title: Text(
                                        device.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Text(
                                            'MAC: \${device.address}',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.6),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                        ),
                                        onPressed: () {
                                          session.connectToDevice(device.address);
                                          // Navigate to the Connected Devices dashboard
                                          context.go('/connected-devices');
                                        },
                                        child: const Text('Connect'),
                                      ),
                                    ),
                                  )
                                      .animate()
                                      .slideY(
                                          begin: 0.1,
                                          duration: 400.ms,
                                          curve: Curves.easeOut)
                                      .fade(),
                                );
                              },
                            )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningRipple() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple 3
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.1), width: 2),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(2.5, 2.5),
                  duration: 2500.ms)
              .fade(begin: 1, end: 0, duration: 2500.ms),

          // Ripple 2
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.3), width: 2),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(2.0, 2.0),
                  duration: 2500.ms,
                  delay: 800.ms)
              .fade(begin: 1, end: 0, duration: 2500.ms, delay: 800.ms),

          // Ripple 1
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.5), width: 3),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.5, 1.5),
                  duration: 2500.ms,
                  delay: 1600.ms)
              .fade(begin: 1, end: 0, duration: 2500.ms, delay: 1600.ms),

          // Center Logo (Smart Myna Bird representation)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A), // Dark center
              border: Border.all(color: Colors.blueAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.flutter_dash_rounded,
                size: 40, color: Colors.blueAccent),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 1200.ms),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6), // Solid dark overlay
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

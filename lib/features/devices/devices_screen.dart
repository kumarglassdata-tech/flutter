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

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().startDiscovery();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final state = session.state;
    final isScanning =
        state.bleConnectionState == GlassesConnectionState.scanning;

    final bleDevices =
        state.discoveredDevices.where((d) => d.linkType != DeviceLinkType.wifi).toList();
    final wifiDevices =
        state.discoveredDevices.where((d) => d.linkType == DeviceLinkType.wifi).toList();

    final canUseMetaSdk = state.metaSdkAvailable;
    final metaDevice = canUseMetaSdk
      ? state.discoveredDevices
        .where((d) => d.name.contains('RB') || d.name.contains('Meta'))
        .firstOrNull
      : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AppShell.openDrawer),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connect Glasses',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text(session.scanStatus,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => session.startDiscovery(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Meta Glasses Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDBEAFE), Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ray-Ban Meta Glasses',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF))),
                  const SizedBox(height: 8),
                  if (metaDevice != null) ...[
                    Text(
                      'Found: ${metaDevice.name} ${metaDevice.isBonded ? "(paired)" : ""}',
                      style: const TextStyle(color: Color(0xFF166534)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await session.connectToMetaGlasses();
                          if (!context.mounted) return;
                          context.push('/devices/${Uri.encodeComponent(metaDevice.address)}');
                        },
                        child: Text('Connect ${metaDevice.name}'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await session.registerMetaGlasses();
                        },
                        child: const Text('Register with Meta View/AI'),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Meta SDK is not active on this runtime. Use Android device build for real Meta connect, or continue with local camera fallback.',
                      style: TextStyle(color: Color(0xFF3B5F8F), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await session.connectToMetaGlasses();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF)),
                        child: const Text('Try Meta connect / fallback'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await session.startDiscovery();
                        },
                        child: const Text('Rescan devices'),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),

          if (isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(color: AppTheme.primary),
            ),

          // Tab Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Bluetooth (${bleDevices.length})'),
                Tab(text: 'Wi-Fi (${wifiDevices.length})'),
              ],
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.onSurfaceVariant,
              indicatorColor: AppTheme.primary,
            ),
          ),

          // Device List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DeviceList(
                    devices: bleDevices,
                    isScanning: isScanning,
                    isWifi: false,
                    scanStatus: session.scanStatus,
                    state: state,
                    onConnect: (addr) {
                      session.connectToDevice(addr);
                      context.push('/devices/${Uri.encodeComponent(addr)}');
                    }),
                _DeviceList(
                    devices: wifiDevices,
                    isScanning: false,
                    isWifi: true,
                    scanStatus: session.scanStatus,
                    state: state,
                    onConnect: (addr) {}),
              ],
            ),
          ),

          // Connection status
          if (state.bleConnectionState != GlassesConnectionState.disconnected)
            _ConnectionStatusBar(state: state, onDisconnect: () => session.stopRuntime()),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  final List<GlassesDevice> devices;
  final bool isScanning;
  final bool isWifi;
  final String scanStatus;
  final SessionState state;
  final void Function(String) onConnect;

  const _DeviceList({
    required this.devices,
    required this.isScanning,
    required this.isWifi,
    required this.scanStatus,
    required this.state,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isScanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_disabled_rounded,
              size: 64,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching nearby…' : 'No devices found yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isWifi
                    ? 'Enable Wi-Fi to see nearby networks.'
                    : 'Turn on Bluetooth and open glasses pairing mode.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = devices[i];
        final isConnected = state.bleConnectionState == GlassesConnectionState.connected &&
            (state.connectedDeviceName == d.name ||
             state.connectedDeviceName == d.address);
        final isMeta = d.name.contains('RB') || d.name.contains('Meta');
        return _DeviceCard(
          device: d,
          isConnected: isConnected,
          isMetaGlasses: isMeta,
          onTap: () => onConnect(d.address),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 80), duration: 300.ms);
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final GlassesDevice device;
  final bool isConnected;
  final bool isMetaGlasses;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.isConnected,
    required this.isMetaGlasses,
    required this.onTap,
  });

  String get _linkLabel {
    switch (device.linkType) {
      case DeviceLinkType.wifi:
        return 'Wi-Fi';
      case DeviceLinkType.classicBt:
        return 'Bluetooth Classic';
      case DeviceLinkType.ble:
        return 'BLE';
      case DeviceLinkType.metaDat:
        return 'Meta DAT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isConnected
          ? Theme.of(context).colorScheme.primaryContainer
          : isMetaGlasses
              ? const Color(0xFFE8F5E9)
              : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  device.linkType == DeviceLinkType.wifi
                      ? Icons.wifi_rounded
                      : Icons.bluetooth_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(device.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (isMetaGlasses) ...[
                          const SizedBox(width: 6),
                          const _Chip(label: 'Meta', color: Color(0xFF166534)),
                        ],
                        if (device.isBonded) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                        ],
                      ],
                    ),
                    Text(_linkLabel,
                        style: const TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 12)),
                    Text(device.address,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (device.rssi != 0)
                      Text('Signal: ${device.rssi} dBm',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              if (isConnected)
                const Text('Connected',
                    style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                        fontSize: 12))
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ConnectionStatusBar extends StatelessWidget {
  final SessionState state;
  final VoidCallback onDisconnect;

  const _ConnectionStatusBar({required this.state, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${state.bleConnectionState.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (state.connectedDeviceName != null)
                  Text(state.connectedDeviceName!,
                      style: const TextStyle(
                          color: AppTheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisconnect,
            child: const Text('Disconnect',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }
}

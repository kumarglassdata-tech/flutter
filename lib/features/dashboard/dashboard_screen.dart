import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';

// Modular Sub-Widgets
import 'widgets/source_input_selector.dart';
import 'widgets/camera_preview_card.dart';
import 'widgets/file_upload_widget.dart';
import 'widgets/session_overview_card.dart';
import 'widgets/api_connectivity_panel.dart';
import 'widgets/engine_card.dart';
import 'widgets/ai_result_card.dart';
import 'widgets/control_panel.dart';
import 'widgets/placeholder_tab.dart';
import 'widgets/normal_user_cards.dart';
import 'widgets/consumer_analytics_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late int _tabCount;

  SessionState? _previousState;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _tabCount = auth.isAdmin ? 5 : 2;
    _tabController = TabController(length: _tabCount, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        final session = context.read<SessionProvider>();
        session.cameraService.initialize(
              preferredLens: settings.preferredCamera == 'FRONT'
                  ? CameraLensDirection.front
                  : CameraLensDirection.back,
            );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final newTabCount = auth.isAdmin ? 5 : 2;
    if (newTabCount != _tabCount) {
      _tabCount = newTabCount;
      final oldController = _tabController;
      _tabController = TabController(length: _tabCount, vsync: this);
      Future.microtask(() => oldController.dispose());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    
    final tabs = isAdmin ? [
      'Dashboard',
      'Analytics',
      'Stats',
      'Reports',
    ] : [
      'Dashboard',
      'Analytics',
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: Builder(
          builder: (_) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: AppShell.openDrawer,
          ),
        ),
        title: const Text(
          'FOP Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: isAdmin ? [
          _MainDashboardContent(settings: settings),
          const PlaceholderTab(title: 'Analytics'),
          const PlaceholderTab(title: 'Stats'),
          const PlaceholderTab(title: 'Reports'),
        ] : [
          _MainDashboardContent(settings: settings),
          const ConsumerAnalyticsTab(),
        ],
      ),
    );
  }
}

class _MainDashboardContent extends StatelessWidget {
  final SettingsProvider settings;

  const _MainDashboardContent({required this.settings});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final auth = context.watch<AuthProvider>();
    final state = session.state;
    final isAdmin = auth.isAdmin;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ControlPanel(
            isActive: state.isSessionActive,
            onStart: () =>
                context.read<SessionProvider>().startRuntime(),
            onStop: () => context.read<SessionProvider>().stopRuntime(),
          ).animate().fadeIn(duration: 400.ms),
        ),
        if (state.isSessionActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.redAccent, size: 16)
                    .animate(onPlay: (controller) => controller.repeat())
                    .fadeOut(duration: 800.ms)
                    .fadeIn(duration: 800.ms),
                const SizedBox(width: 8),
                const Text(
                  'Listening...',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [


          if (session.sourceManager.activeType == SourceType.phone)
            CameraPreviewCard(
              cameraService: session.cameraService,
              lastContextOutput: state.lastContextOutput,
              onFlipCamera: () async {
                await session.cameraService.toggleCameraLens();
                await settings.setPreferredCamera(
                  session.cameraService.preferredLens == CameraLensDirection.front
                      ? 'FRONT'
                      : 'BACK',
                );
              },
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08)
          else if (session.sourceManager.activeType == SourceType.videoUpload)
            const FileUploadWidget()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      session.sourceManager.activeType == SourceType.mock
                          ? Icons.auto_awesome_rounded
                          : Icons.computer_rounded,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.sourceManager.activeType == SourceType.mock
                            ? 'Streaming simulated mock data...'
                            : state.connectedDeviceName != null ? 'Connected to ${state.connectedDeviceName} feed' : 'Connected to stream',
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

          if (isAdmin) ...[
            const SizedBox(height: 16),
            const SourceInputSelector()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08),
          ],

          const SizedBox(height: 16),
          // Normal User + Admin Cards
          NormalUserCards(state: state)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1),

          if (isAdmin) ...[
            const SizedBox(height: 16),
            // Session overview card
            SessionOverviewCard(state: state)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: 16),
            // API Connection Diagnostics Panel
            const ApiConnectivityPanel()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: 16),

            // Engine status cards
            EngineCard(
              title: 'Glasses Engine',
              engineState: state.glassesState,
              icon: Icons.bluetooth_rounded,
              metrics: [
                ('Device', state.connectedDeviceName ?? 'None'),
                ('RSSI', '${state.bleRssi} dBm'),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 12),

            EngineCard(
              title: 'Media Engine',
              engineState: state.mediaState,
              icon: Icons.camera_alt_rounded,
              metrics: [
                ('FPS', state.mediaFps.toStringAsFixed(1)),
                ('Emitted', state.framesEmitted.toString()),
                ('Dropped', state.framesDropped.toString()),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 12),

            EngineCard(
              title: 'AI Engine',
              engineState: state.aiState,
              icon: Icons.psychology_rounded,
              metrics: [
                ('Throughput', '${state.aiThroughputFps.toStringAsFixed(1)} fps'),
                ('Latency', '${state.aiLatencyMs.toStringAsFixed(0)} ms'),
                ('RTT', '${state.rttMs} ms'),
              ],
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

            // AI Result
            if (state.lastAiResult != null) ...[
              const SizedBox(height: 12),
              AiResultCard(result: state.lastAiResult!)
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .scale(begin: const Offset(0.95, 0.95)),
            ],
          ],

          if (isAdmin && state.modelOutputs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model Outputs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...state.modelOutputs.entries.map((e) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key),
                            Text(e.value.toStringAsFixed(3)),
                          ],
                        )),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 480.ms),
          ],

          if (isAdmin && state.modelContext != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model Context',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(state.modelContext),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 490.ms),
          ],

              ],
            ),
          ),
        ),
      ],
    );
  }
}

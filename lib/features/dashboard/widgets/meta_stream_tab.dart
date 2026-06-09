import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/features/dashboard/widgets/bounding_box_overlay.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class MetaStreamTab extends StatelessWidget {
  const MetaStreamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final state = session.state;
    final jsonText = state.modelContext != null
        ? const JsonEncoder.withIndent('  ').convert(state.modelContext)
        : '{\n  "message": "Start runtime to see the structured pipeline JSON here."\n}';
    final isConnected = state.bleConnectionState == GlassesConnectionState.connected;

    final isBusy = session.isConnecting || session.isStartingRuntime;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MetaStreamPreviewCard(
            frameBytes: state.metaFrameBytes,
            isStreaming: state.isSessionActive && state.usingRealMetaStream,
            isConnected: isConnected,
            onConnect: isBusy
                ? null
                : () async {
                    await session.connectToMetaGlasses(useMock: settings.useMockMeta);
                  },
            onStartStream: isBusy
                ? null
                : () async {
                    await session.startRuntime(useMock: settings.useMockMeta);
                  },
            lastContextOutput: state.lastContextOutput,
          ),
          const SizedBox(height: 16),
          if (!auth.isAdmin)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pipeline Payload Locked',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please log in as an administrator to unlock direct orchestrator pipeline JSON outputs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          settings.useMockMeta ? 'Meta Glass Stream (Mock)' : 'Meta Glass Stream',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          state.isSessionActive ? 'LIVE' : 'IDLE',
                          style: TextStyle(
                            color: state.isSessionActive
                                ? const Color(0xFF16A34A)
                                : AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Structured orchestrator pipeline output: context, behavior, interaction, ecom, memory',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        jsonText,
                        style: const TextStyle(
                          color: Color(0xFF4ADE80),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () async {
                                if (isConnected) {
                                  await session.startRuntime(useMock: settings.useMockMeta);
                                } else {
                                  await session.connectToMetaGlasses(useMock: settings.useMockMeta);
                                }
                              },
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(isConnected ? Icons.play_arrow_rounded : Icons.link_rounded),
                        label: Text(
                          isBusy
                              ? (isConnected ? 'Starting Stream...' : 'Connecting...')
                              : (isConnected ? 'Start Meta Stream' : 'Connect Meta Glasses'),
                        ),
                        style: isConnected
                            ? ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                               )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MetaStreamPreviewCard extends StatelessWidget {
  final Uint8List? frameBytes;
  final bool isStreaming;
  final bool isConnected;
  final VoidCallback? onConnect;
  final VoidCallback? onStartStream;
  final ContextEngineOutput? lastContextOutput;

  const MetaStreamPreviewCard({
    super.key,
    required this.frameBytes,
    required this.isStreaming,
    required this.isConnected,
    this.onConnect,
    this.onStartStream,
    this.lastContextOutput,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF60A5FA), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ray-Ban Meta Glasses Feed',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isStreaming
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : isConnected
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                              : const Color(0xFF64748B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isStreaming
                                ? const Color(0xFF34D399)
                                : isConnected
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isStreaming
                              ? 'Streaming'
                              : isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                          style: TextStyle(
                            color: isStreaming
                                ? const Color(0xFF34D399)
                                : isConnected
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: isStreaming && frameBytes != null
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              frameBytes!,
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (lastContextOutput != null)
                          Positioned.fill(
                            child: BoundingBoxOverlay(
                              lastContextOutput: lastContextOutput,
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFF1E293B),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off_rounded,
                            color: Color(0xFF64748B),
                            size: 36,
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .scale(end: const Offset(1.1, 1.1), duration: 2.seconds),
                          const SizedBox(height: 8),
                          Text(
                            isConnected
                                ? 'Meta glasses are connected. Ready to start streaming.'
                                : 'Meta glasses stream is currently offline.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: isConnected ? onStartStream : onConnect,
                            icon: (onConnect == null && onStartStream == null)
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isConnected ? Icons.play_arrow_rounded : Icons.link_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              (onConnect == null && onStartStream == null)
                                  ? (isConnected ? 'Starting Stream...' : 'Connecting...')
                                  : (isConnected ? 'Start Meta Stream' : 'Connect Meta Glasses'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isConnected ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

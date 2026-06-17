import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'bounding_box_overlay.dart';
import 'mini_metric.dart';

class CameraPreviewCard extends StatelessWidget {
  final CameraService cameraService;
  final ContextEngineOutput? lastContextOutput;
  final Future<void> Function()? onFlipCamera;

  const CameraPreviewCard({
    super.key,
    required this.cameraService,
    this.lastContextOutput,
    this.onFlipCamera,
  });

  @override
  Widget build(BuildContext context) {
    final controller = cameraService.controller;
    final telemetry = cameraService.telemetry;
    final isReady = controller != null && controller.value.isInitialized;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Live Camera Stream', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (onFlipCamera != null)
                  IconButton(
                    tooltip: 'Flip camera',
                    onPressed: () => onFlipCamera!(),
                    icon: const Icon(Icons.cameraswitch_rounded),
                  ),
                Text(
                  cameraService.isStreaming ? 'Streaming' : 'Idle',
                  style: TextStyle(
                    color: cameraService.isStreaming ? const Color(0xFF16A34A) : AppTheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          isReady
              ? SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: (controller.value.previewSize?.height ?? 1080.0) < (controller.value.previewSize?.width ?? 1920.0) ? (controller.value.previewSize?.height ?? 1080.0) : (controller.value.previewSize?.width ?? 1920.0),
                        height: (controller.value.previewSize?.height ?? 1080.0) > (controller.value.previewSize?.width ?? 1920.0) ? (controller.value.previewSize?.height ?? 1080.0) : (controller.value.previewSize?.width ?? 1920.0),
                        child: Stack(
                          children: [
                            Positioned.fill(child: CameraPreview(controller)),
                            if (isAdmin && lastContextOutput != null)
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: BoundingBoxOverlay(
                                    lastContextOutput: lastContextOutput,
                                    imageSize: Size(
                                      (controller.value.previewSize?.height ?? 1080.0) < (controller.value.previewSize?.width ?? 1920.0) ? (controller.value.previewSize?.height ?? 1080.0) : (controller.value.previewSize?.width ?? 1920.0),
                                      (controller.value.previewSize?.height ?? 1080.0) > (controller.value.previewSize?.width ?? 1920.0) ? (controller.value.previewSize?.height ?? 1080.0) : (controller.value.previewSize?.width ?? 1920.0)
                                    ),
                                    isMirrored: cameraService.preferredLens == CameraLensDirection.front,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_back_rounded, color: AppTheme.onSurfaceVariant, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          cameraService.errorMessage ?? 'Initialize the camera or start the runtime to begin streaming.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  MiniMetric(label: 'Frames', value: telemetry.framesCaptured.toString()),
                  MiniMetric(label: 'Dropped', value: telemetry.framesDropped.toString()),
                  MiniMetric(label: 'FPS', value: telemetry.cameraFps.toStringAsFixed(1)),
                  MiniMetric(label: 'Latency', value: '${telemetry.lastAnalysisLatencyMs.toStringAsFixed(0)} ms'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

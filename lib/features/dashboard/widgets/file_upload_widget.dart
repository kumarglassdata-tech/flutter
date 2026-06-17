import 'dart:io' as io;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/sources/video_upload/video_upload_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';
import 'bounding_box_overlay.dart';

class FileUploadWidget extends StatefulWidget {
  const FileUploadWidget({super.key});

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final activeAdapter = session.sourceManager.activeAdapter;

    final isVideoActive = activeAdapter is VideoUploadSourceAdapter;
    final fileName = isVideoActive ? (activeAdapter as VideoUploadSourceAdapter).fileName : null;
    final isImage = isVideoActive ? (activeAdapter as VideoUploadSourceAdapter).isImage : false;
    final hasFile = fileName != null;
    final isSessionActive = session.state.isSessionActive;
    final state = session.state;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.video_library_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Video / Image File Ingestion',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasFile) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isImage ? Icons.image_rounded : Icons.movie_creation_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isImage ? 'Source Type: Image File' : 'Source Type: Video File',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPicking ? null : _pickFile,
                icon: _isPicking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.file_open_rounded),
                label: Text(hasFile ? 'Change File Source' : 'Upload Video or Image'),
              ),
            ),
            if (hasFile && isSessionActive) ...[
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        if (state.metaFrameBytes != null)
                          Positioned.fill(
                            child: Image.memory(
                              state.metaFrameBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_empty_rounded,
                                  color: Colors.white54,
                                  size: 36,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Processing frame...',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        Positioned.fill(
                          child: BoundingBoxOverlay(
                            lastContextOutput: state.lastContextOutput,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isImage) ...[
                const SizedBox(height: 16),
                const SimulatedVideoPlayback(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        final name = platformFile.name;
        final nameLower = name.toLowerCase();
        final isImage = nameLower.endsWith('.jpg') ||
            nameLower.endsWith('.jpeg') ||
            nameLower.endsWith('.png') ||
            nameLower.endsWith('.webp') ||
            nameLower.endsWith('.gif');

        Uint8List bytes;
        if (kIsWeb) {
          bytes = platformFile.bytes!;
        } else {
          if (platformFile.bytes != null) {
            bytes = platformFile.bytes!;
          } else {
            final file = io.File(platformFile.path!);
            bytes = await file.readAsBytes();
          }
        }

        if (mounted) {
          final session = context.read<SessionProvider>();
          session.setUploadedFile(bytes, name, isImage);
          session.sourceManager.switchSource(SourceType.videoUpload);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded file source set to: $name')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }
}

class SimulatedVideoPlayback extends StatefulWidget {
  const SimulatedVideoPlayback({super.key});

  @override
  State<SimulatedVideoPlayback> createState() => _SimulatedVideoPlaybackState();
}

class _SimulatedVideoPlaybackState extends State<SimulatedVideoPlayback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_fill, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Streaming frames from video file...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(_animController.value * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _animController.value,
                color: Colors.green,
                backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
          ],
        );
      },
    );
  }
}

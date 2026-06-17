import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:smartglass_flutter/core/orchestrator/pipeline_coordinator.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';
import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/diagnostics/telemetry_service.dart';
import 'package:smartglass_flutter/core/sources/video_upload/video_upload_source_adapter.dart';

class StreamCoordinator extends ChangeNotifier {
  final SourceManager _sourceManager;
  final PipelineCoordinator _pipelineCoordinator;
  final TelemetryService _telemetryService;

  StreamSubscription<VideoFrame>? _videoSub;
  StreamSubscription<AudioChunk>? _audioSub;
  StreamSubscription<LocationData>? _locationSub;

  final Map<String, dynamic>? Function()? getActiveVoiceNlu;

  // Latests stashed sensor data
  AudioChunk? _latestAudio;
  LocationData? _latestLocation;
  VideoFrame? _stashedVideoFrame;
  VideoFrame? _latestProcessedFrame;

  bool _isPipelineBusy = false;
  bool _isRunning = false;
  Map<String, dynamic> _lastResult = {};

  StreamCoordinator({
    required SourceManager sourceManager,
    required PipelineCoordinator pipelineCoordinator,
    required TelemetryService telemetryService,
    this.getActiveVoiceNlu,
  })  : _sourceManager = sourceManager,
        _pipelineCoordinator = pipelineCoordinator,
        _telemetryService = telemetryService;

  bool get isRunning => _isRunning;
  bool get isPipelineBusy => _isPipelineBusy;
  Map<String, dynamic> get lastResult => _lastResult;
  VideoFrame? get latestProcessedFrame => _latestProcessedFrame;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 1. Subscribe to location updates independently
    _locationSub = _sourceManager.locationStream.listen((loc) {
      _latestLocation = loc;
    });

    // 2. Subscribe to audio updates independently
    _audioSub = _sourceManager.audioStream.listen((audio) {
      _latestAudio = audio;
    });

    // 3. Subscribe to video frame updates (with LatestFrameWins queue policy)
    _videoSub = _sourceManager.videoStream.listen((frame) {
      _telemetryService.incrementCapturedFrames();
      _handleIncomingVideoFrame(frame);
    });

    _sourceManager.startActive();
    notifyListeners();
  }

  void _handleIncomingVideoFrame(VideoFrame frame) {
    if (_isPipelineBusy) {
      // LatestFrameWins Drop Policy:
      // Discard previously stashed stale frame, keep the freshest frame only.
      if (_stashedVideoFrame != null) {
        _telemetryService.incrementDroppedFrames();
      }
      _stashedVideoFrame = frame;
      _telemetryService.updateQueueDepth(1);
    } else {
      _stashedVideoFrame = null;
      _telemetryService.updateQueueDepth(0);
      _executePipeline(frame);
    }
  }

  Future<void> _executePipeline(VideoFrame frame) async {
    _latestProcessedFrame = frame;
    _isPipelineBusy = true;
    notifyListeners();

    Map<String, dynamic>? metadata;
    if (_sourceManager.activeType == SourceType.videoUpload) {
      final adapter = _sourceManager.activeAdapter;
      if (adapter is VideoUploadSourceAdapter) {
        metadata = {
          "mediaType": adapter.isImage ? "image" : "video",
          "decodeMode": adapter.isImage ? "direct" : "fallback",
          "decodeSupported": adapter.isImage,
        };
      }
    }

    final input = UnifiedInput(
      imageBytes: frame.bytes,
      audioBytes: null, // UnifiedInput audioBytes is Uint8List?, AudioChunk has List<double>. Conversion happens elsewhere if needed.
      latitude: _latestLocation?.latitude,
      longitude: _latestLocation?.longitude,
      source: _sourceManager.activeType == SourceType.meta
          ? InputSource.META
          : (_sourceManager.activeType == SourceType.phone ? InputSource.PHONE : InputSource.MOCK),
      timestamp: DateTime.now(),
      metadata: {
        ...(metadata ?? {}),
        if (getActiveVoiceNlu != null && getActiveVoiceNlu!() != null)
          'voice_nlu': getActiveVoiceNlu!(),
      },
    );

    try {
      final result = await _pipelineCoordinator.runPipeline(input);
      _lastResult = result;
    } catch (e) {
      debugPrint('StreamCoordinator: Terminal Pipeline Failure: $e');
      _lastResult = {'pipeline.error': e.toString()};
    } finally {
      _isPipelineBusy = false;
      notifyListeners();

      // Check if another frame was stashed while we were busy
      final nextFrame = _stashedVideoFrame;
      if (nextFrame != null && _isRunning) {
        _stashedVideoFrame = null;
        _telemetryService.updateQueueDepth(0);
        // Dequeue next latest frame asynchronously to prevent stack overflow
        Future.microtask(() => _executePipeline(nextFrame));
      }
    }
  }

  void stop() {
    _isRunning = false;
    _isPipelineBusy = false;
    _videoSub?.cancel();
    _videoSub = null;
    _audioSub?.cancel();
    _audioSub = null;
    _locationSub?.cancel();
    _locationSub = null;
    _stashedVideoFrame = null;
    _latestProcessedFrame = null;

    _sourceManager.stopActive();
    _telemetryService.clearMetrics();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

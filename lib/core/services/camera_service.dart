import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraTelemetry {
  final bool isInitialized;
  final bool isStreaming;
  final int framesCaptured;
  final int framesDropped;
  final double cameraFps;
  final double analysisThroughputFps;
  final double lastAnalysisLatencyMs;
  final String? lastFramePath;
  final Uint8List? lastFrameBytes;
  final String? errorMessage;

  const CameraTelemetry({
    required this.isInitialized,
    required this.isStreaming,
    required this.framesCaptured,
    required this.framesDropped,
    required this.cameraFps,
    required this.analysisThroughputFps,
    required this.lastAnalysisLatencyMs,
    required this.lastFramePath,
    this.lastFrameBytes,
    required this.errorMessage,
  });
}

class CameraService extends ChangeNotifier {
  CameraService();

  static const Duration _captureInterval = Duration(seconds: 3);

  CameraController? _controller;
  Timer? _timer;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _captureInFlight = false;
  CameraLensDirection _preferredLens = CameraLensDirection.back;
  int _framesCaptured = 0;
  int _framesDropped = 0;
  int _analysisCount = 0;
  DateTime? _streamStartedAt;
  double _lastAnalysisLatencyMs = 0;
  String? _lastFramePath;
  Uint8List? _lastFrameBytes;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  CameraLensDirection get preferredLens => _preferredLens;
  String? get errorMessage => _errorMessage;

  CameraTelemetry get telemetry {
    final elapsedSeconds = math.max(
      1,
      DateTime.now().difference(_streamStartedAt ?? DateTime.now()).inMilliseconds ~/ 1000,
    );
    return CameraTelemetry(
      isInitialized: _isInitialized,
      isStreaming: _isStreaming,
      framesCaptured: _framesCaptured,
      framesDropped: _framesDropped,
      cameraFps: _framesCaptured / elapsedSeconds,
      analysisThroughputFps: _analysisCount / elapsedSeconds,
      lastAnalysisLatencyMs: _lastAnalysisLatencyMs,
      lastFramePath: _lastFramePath,
      lastFrameBytes: _lastFrameBytes,
      errorMessage: _errorMessage,
    );
  }

  Future<void> initialize({CameraLensDirection preferredLens = CameraLensDirection.back}) async {
    if (_isInitialized) return;

    _preferredLens = preferredLens;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _errorMessage = 'No cameras available on this device.';
        notifyListeners();
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == preferredLens,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Camera initialization failed: $error';
      notifyListeners();
    }
  }

  Future<void> startStreaming() async {
    await initialize(preferredLens: _preferredLens);
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _streamStartedAt ??= DateTime.now();
    _isStreaming = true;
    _timer?.cancel();
    _timer = Timer.periodic(_captureInterval, (_) {
      _captureFrame();
    });
    notifyListeners();
    await _captureFrame();
  }

  Future<void> stopStreaming() async {
    _timer?.cancel();
    _timer = null;
    _isStreaming = false;
    notifyListeners();
  }

  Future<void> toggleCameraLens() async {
    final wasStreaming = _isStreaming;
    _timer?.cancel();
    _timer = null;
    _isStreaming = false;
    _streamStartedAt = null;

    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _errorMessage = null;
    _preferredLens = _preferredLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    notifyListeners();

    await initialize(preferredLens: _preferredLens);
    if (wasStreaming) {
      await startStreaming();
    }
  }

  Future<void> _captureFrame() async {
    if (!_isStreaming || _captureInFlight || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _captureInFlight = true;
    final startedAt = DateTime.now();
    try {
      final picture = await _controller!.takePicture();
      final Uint8List bytes = await picture.readAsBytes();
      _lastFramePath = picture.path;
      _lastFrameBytes = bytes;
      
      // Delete temporary picture file to prevent disk fill-up and I/O degradation
      if (!kIsWeb) {
        try {
          final file = File(picture.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('CameraService: Failed to delete temp picture file: $e');
        }
      }

      _framesCaptured += 1;
      _analysisCount += 1;
      _lastAnalysisLatencyMs = DateTime.now().difference(startedAt).inMilliseconds.toDouble();
      _errorMessage = null;
    } catch (error) {
      _framesDropped += 1;
      _errorMessage = 'Frame capture failed: $error';
    } finally {
      _captureInFlight = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
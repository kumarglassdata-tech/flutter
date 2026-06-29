import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

class CameraService extends ChangeNotifier with WidgetsBindingObserver {
  CameraService() {
    WidgetsBinding.instance.addObserver(this);
  }

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
  Size? _captureResolution;
  Size? get captureResolution => _captureResolution;

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      _isInitialized = true;
      _errorMessage = null;
      debugPrint('[CameraService] Initialized successfully');
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Camera initialization failed: $error';
      debugPrint('[CameraService] $_errorMessage');
      notifyListeners();
    }
  }

  Timer? _captureTimer;

  Future<void> startStreaming() async {
    await initialize(preferredLens: _preferredLens);
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _streamStartedAt ??= DateTime.now();
    _isStreaming = true;
    _errorMessage = null;
    notifyListeners();

    // Take a picture every 2 seconds to avoid overloading the HAL
    _captureTimer = Timer.periodic(const Duration(milliseconds: 2000), _captureFrame);
  }

  Future<void> _captureFrame(Timer timer) async {
    if (!_isStreaming || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (_captureInFlight) return; // STRICT CONCURRENCY LOCK

    _captureInFlight = true;
    final startedAt = DateTime.now();
    
    try {
      final picture = await _controller!.takePicture();
      final bytes = await picture.readAsBytes();

      _lastFrameBytes = bytes;
      _lastFramePath = picture.path;

      // Ensure we have a resolution recorded
      // We can't get it directly from picture object easily here without decoding, 
      // but backend handles JPEG decoding.

      _framesCaptured += 1;
      _analysisCount += 1;
      _lastAnalysisLatencyMs = DateTime.now().difference(startedAt).inMilliseconds.toDouble();
      _errorMessage = null;

      // Delete the file immediately to avoid mFd leaks!
      try {
        await File(picture.path).delete();
      } catch (_) {}
    } catch (error) {
      _framesDropped += 1;
      _errorMessage = 'Frame capture failed: $error';
    } finally {
      _captureInFlight = false;
      notifyListeners();
    }
  }



  Future<void> stopStreaming() async {
    _isStreaming = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    notifyListeners();
  }

  Future<void> toggleCameraLens() async {
    final wasStreaming = _isStreaming;
    await stopStreaming();
    _streamStartedAt = null;

    // WAIT for any active capture to finish before disposing the hardware!
    while (_captureInFlight) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Give the MTK Camera HAL a tiny buffer to flush its file descriptors
    await Future.delayed(const Duration(milliseconds: 200));

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Free up memory when camera not active
      stopStreaming();
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      debugPrint('[CameraService] App went to background. Camera disposed.');
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      debugPrint('[CameraService] App resumed. Re-initializing camera...');
      startStreaming();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopStreaming();
    _controller?.dispose();
    super.dispose();
  }
}
import 'dart:async';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';

class PhoneSourceAdapter implements SourceAdapter {
  final CameraService _cameraService;
  final LocationService _locationService;

  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  bool _isActive = false;
  Timer? _healthTimer;

  PhoneSourceAdapter({
    required CameraService camera,
    required LocationService location,
  })  : _cameraService = camera,
        _locationService = location;

  @override
  Stream<VideoFrame> get videoStream => _videoController.stream;

  @override
  Stream<AudioChunk> get audioStream => _audioController.stream;

  @override
  Stream<LocationData> get locationStream => _locationController.stream;

  @override
  Stream<SourceHealth> get healthStream => _healthController.stream;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    // Start local services
    await _cameraService.startStreaming();
    // await _audioService.start(); // Disabled to allow AudioStreamManager to own the mic
    await _locationService.start();

    // Listeners
    _cameraService.addListener(_onCameraChanged);
    _locationService.addListener(_onLocationChanged);

    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _healthController.add(const SourceHealth(
        status: SourceHealthStatus.healthy,
        message: 'Phone sensors active',
      ));
    });

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.healthy,
      message: 'Phone Source Adapter Started',
    ));
  }

  void _onCameraChanged() {
    final bytes = _cameraService.telemetry.lastFrameBytes;
    if (bytes != null && bytes.isNotEmpty) {
      _videoController.add(VideoFrame(bytes: bytes, width: 0, height: 0));
    }
  }

  void _onAudioChanged() {
  }

  void _onLocationChanged() {
    if (_locationService.latitude != null && _locationService.longitude != null) {
      _locationController.add(LocationData(
        latitude: _locationService.latitude!,
        longitude: _locationService.longitude!,
      ));
    }
  }

  @override
  Future<void> stop() async {
    _isActive = false;
    _cameraService.removeListener(_onCameraChanged);
    _locationService.removeListener(_onLocationChanged);
    _healthTimer?.cancel();
    _healthTimer = null;

    await _cameraService.stopStreaming();
    await _locationService.stop();

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.disconnected,
      message: 'Phone source stopped',
    ));
  }

  void dispose() {
    stop();
    _videoController.close();
    _audioController.close();
    _locationController.close();
    _healthController.close();
  }
}

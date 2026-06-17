import 'dart:async';
import 'dart:typed_data';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/services/meta_glasses_sdk_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';

/// Adapter for Ray-Ban Meta Gen-2 Glasses.
/// Coordinates native hardware lifecycle through native platform channels:
/// Flutter Layer -> MetaSdkService -> MethodChannel/EventChannel -> Android Native DAT SDK
class MetaSourceAdapter implements SourceAdapter {
  final MetaGlassesSdkService _metaSdkService;
  final LocationService _locationService;

  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  StreamSubscription<Uint8List>? _sdkStreamSubscription;
  StreamSubscription<double>? _audioSubscription;
  Timer? _healthTimer;
  bool _isActive = false;

  MetaSourceAdapter({
    required MetaGlassesSdkService metaSdk,
    required LocationService location,
  })  : _metaSdkService = metaSdk,
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

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.healthy,
      message: 'Connecting to Ray-Ban Meta Glasses via DAT SDK...',
    ));

    try {
      // 1. Check SDK availability
      final isAvailable = await _metaSdkService.isSdkAvailable();
      if (!isAvailable) {
        _healthController.add(const SourceHealth(
          status: SourceHealthStatus.degraded,
          message: 'Meta SDK is not active on this environment.',
        ));
      }

      // 2. Start native video stream subscription
      _sdkStreamSubscription?.cancel();
      _sdkStreamSubscription = _metaSdkService.videoFrameStream.listen(
        (bytes) {
          _videoController.add(VideoFrame(bytes: bytes, width: 0, height: 0));
        },
        onError: (err) {
          _healthController.add(SourceHealth(
            status: SourceHealthStatus.degraded,
            message: 'Stream Error: $err',
          ));
        },
      );

      // Audio is managed natively by AudioStreamManager
      _audioSubscription?.cancel();

      // Listen to location changes
      _locationService.addListener(_onLocationChanged);

      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _healthController.add(const SourceHealth(
          status: SourceHealthStatus.healthy,
          message: 'Meta connection active',
          batteryLevel: 85, // Stub battery info from SDK
        ));
      });

    } catch (e) {
      _healthController.add(SourceHealth(
        status: SourceHealthStatus.disconnected,
        message: 'DAT SDK Link Failed: $e',
      ));
    }
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
    _sdkStreamSubscription?.cancel();
    _sdkStreamSubscription = null;
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _locationService.removeListener(_onLocationChanged);
    _healthTimer?.cancel();
    _healthTimer = null;

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.disconnected,
      message: 'Meta glasses disconnected',
      batteryLevel: 0,
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

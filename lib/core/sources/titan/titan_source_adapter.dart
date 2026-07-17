import 'dart:async';
import 'dart:typed_data';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/services/titan_sdk_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';

/// Adapter for Titan Glasses.
/// Coordinates native hardware lifecycle through native platform channels.
class TitanSourceAdapter implements SourceAdapter {
  final TitanSdkService _titanSdkService;
  final LocationService _locationService;

  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _healthTimer;
  bool _isActive = false;

  TitanSourceAdapter({
    required TitanSdkService titanSdk,
    required LocationService location,
  })  : _titanSdkService = titanSdk,
        _locationService = location;

  @override
  bool get isActive => _isActive;

  @override
  Stream<VideoFrame> get videoStream => _videoController.stream;

  @override
  Stream<AudioChunk> get audioStream => _audioController.stream;

  @override
  Stream<LocationData> get locationStream => _locationController.stream;

  @override
  Stream<SourceHealth> get healthStream => _healthController.stream;

  @override
  Future<void> start() async {
    _isActive = true;
    _startHealthMonitoring();
    _broadcastHealth(const SourceHealth(status: SourceHealthStatus.healthy, message: 'Titan Stream Started'));

    // Start Audio
    final started = await _titanSdkService.startAudio();
    if (started) {
      _audioSubscription?.cancel();
      _audioSubscription = _titanSdkService.audioStream.listen(
        (pcmData) {
          final bd = ByteData.view(pcmData.buffer);
          final samples = <double>[];
          for (int i = 0; i < pcmData.length - 1; i += 2) {
            samples.add(bd.getInt16(i, Endian.little) / 32768.0);
          }
          _audioController.add(AudioChunk(
            samples,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        },
        onError: (e) {
          print("Titan audio error: \$e");
        },
      );
    }
  }

  @override
  Future<void> stop() async {
    _isActive = false;
    _healthTimer?.cancel();
    
    await _titanSdkService.stopAudio();
    _audioSubscription?.cancel();
    _audioSubscription = null;

    _broadcastHealth(const SourceHealth(status: SourceHealthStatus.disconnected, message: 'Titan Stream Stopped'));
  }

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isActive) {
        _broadcastHealth(const SourceHealth(status: SourceHealthStatus.healthy, message: 'Titan OK'));
      }
    });
  }

  void _broadcastHealth(SourceHealth health) {
    if (!_healthController.isClosed) {
      _healthController.add(health);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _videoController.close();
    await _audioController.close();
    await _locationController.close();
    await _healthController.close();
  }
}

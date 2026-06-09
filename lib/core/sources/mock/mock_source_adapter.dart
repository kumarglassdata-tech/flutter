import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';

class MockSourceAdapter implements SourceAdapter {
  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  Timer? _timer;
  bool _isActive = false;
  double _lat = 37.4219999;
  double _lng = -122.0840575;
  int _battery = 100;

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
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isActive) return;

      // 1. Emit Video (mock empty frame bytes)
      _videoController.add(VideoFrame(
        bytes: Uint8List.fromList([0, 1, 2, 3]),
        width: 128,
        height: 128,
      ));

      // 2. Emit Audio (fluctuating samples list)
      final rng = math.Random();
      _audioController.add(AudioChunk(
        List.generate(5, (_) => rng.nextDouble()),
      ));

      // 3. Emit Location (jittered GPS coordinates)
      _lat += (rng.nextDouble() - 0.5) * 0.0001;
      _lng += (rng.nextDouble() - 0.5) * 0.0001;
      _locationController.add(LocationData(
        latitude: _lat,
        longitude: _lng,
      ));

      // 4. Emit Health (draining battery mock)
      if (timer.tick % 5 == 0 && _battery > 1) {
        _battery--;
      }
      _healthController.add(SourceHealth(
        status: SourceHealthStatus.healthy,
        message: 'Mock device active & operating normal',
        batteryLevel: _battery,
      ));
    });

    // Send initial healthy status
    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.healthy,
      message: 'Mock Source Adapter Initialized',
      batteryLevel: 100,
    ));
  }

  @override
  Future<void> stop() async {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.disconnected,
      message: 'Mock source stopped',
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

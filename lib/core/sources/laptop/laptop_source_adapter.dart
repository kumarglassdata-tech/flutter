import 'dart:async';
import 'dart:typed_data';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';

class LaptopSourceAdapter implements SourceAdapter {
  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  bool _isActive = false;
  Timer? _timer;

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

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isActive) return;
      _videoController.add(VideoFrame(bytes: Uint8List.fromList([1, 2, 3]), width: 0, height: 0));
      _audioController.add(AudioChunk([0.1]));
      _locationController.add(LocationData(latitude: 37.7749, longitude: -122.4194));
      _healthController.add(const SourceHealth(
        status: SourceHealthStatus.healthy,
        message: 'Laptop webcam & mic online',
      ));
    });

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.healthy,
      message: 'Laptop Source Adapter Initialized',
    ));
  }

  @override
  Future<void> stop() async {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.disconnected,
      message: 'Laptop source stopped',
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

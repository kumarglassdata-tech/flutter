import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';

enum SourceType { meta, phone, laptop, mock, videoUpload }

class SourceManager extends ChangeNotifier {
  final Map<SourceType, SourceAdapter> _adapters;
  SourceType _activeType = SourceType.mock;
  SourceHealth _currentHealth = const SourceHealth(status: SourceHealthStatus.disconnected, message: 'Initialized');

  StreamSubscription<VideoFrame>? _videoSub;
  StreamSubscription<AudioChunk>? _audioSub;
  StreamSubscription<LocationData>? _locationSub;
  StreamSubscription<SourceHealth>? _healthSub;

  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();

  SourceManager(this._adapters) {
    // Start default mock adapter
    _bindStreams(_adapters[_activeType]!);
  }

  SourceType get activeType => _activeType;
  SourceAdapter get activeAdapter => _adapters[_activeType]!;
  SourceHealth get currentHealth => _currentHealth;

  Stream<VideoFrame> get videoStream => _videoController.stream;
  Stream<AudioChunk> get audioStream => _audioController.stream;
  Stream<LocationData> get locationStream => _locationController.stream;

  Future<void> switchSource(SourceType type) async {
    if (_activeType == type && activeAdapter.isActive) return;

    // 1. Stop current source
    await activeAdapter.stop();
    _unbindStreams();

    // 2. Switch type
    _activeType = type;
    final nextAdapter = _adapters[type]!;

    // 3. Bind and Start next source
    _bindStreams(nextAdapter);
    await nextAdapter.start();

    notifyListeners();
  }

  void _bindStreams(SourceAdapter adapter) {
    _videoSub = adapter.videoStream.listen((frame) => _videoController.add(frame));
    _audioSub = adapter.audioStream.listen((chunk) => _audioController.add(chunk));
    _locationSub = adapter.locationStream.listen((loc) => _locationController.add(loc));
    _healthSub = adapter.healthStream.listen((health) {
      _currentHealth = health;
      notifyListeners();

      // Trigger auto-fallback if Meta fails
      if (_activeType == SourceType.meta && health.status == SourceHealthStatus.disconnected) {
        debugPrint('SourceManager: Meta disconnected! Executing auto-fallback to Phone.');
        switchSource(SourceType.phone);
      }
    });
  }

  void _unbindStreams() {
    _videoSub?.cancel();
    _audioSub?.cancel();
    _locationSub?.cancel();
    _healthSub?.cancel();
  }

  Future<void> startActive() async {
    await activeAdapter.start();
  }

  Future<void> stopActive() async {
    await activeAdapter.stop();
  }

  @override
  void dispose() {
    _unbindStreams();
    _videoController.close();
    _audioController.close();
    _locationController.close();
    for (final adapter in _adapters.values) {
      adapter.stop();
    }
    super.dispose();
  }
}

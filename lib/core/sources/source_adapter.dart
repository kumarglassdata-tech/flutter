import 'package:smartglass_flutter/core/models/unified_input.dart';

enum SourceHealthStatus { healthy, degraded, disconnected }

class SourceHealth {
  final SourceHealthStatus status;
  final String message;
  final int batteryLevel;

  const SourceHealth({
    required this.status,
    required this.message,
    this.batteryLevel = 100,
  });
}

abstract class SourceAdapter {
  Stream<VideoFrame> get videoStream;
  Stream<AudioChunk> get audioStream;
  Stream<LocationData> get locationStream;
  Stream<SourceHealth> get healthStream;

  Future<void> start();
  Future<void> stop();
  bool get isActive;
}

import 'package:flutter/foundation.dart';

class TelemetryService extends ChangeNotifier {
  final Map<String, int> _latencies = {};
  int _droppedFrames = 0;
  int _capturedFrames = 0;
  int _queueDepth = 0;
  int _retryCount = 0;
  double _fps = 0.0;

  Map<String, int> get latencies => _latencies;
  int get droppedFrames => _droppedFrames;
  int get capturedFrames => _capturedFrames;
  int get queueDepth => _queueDepth;
  int get retryCount => _retryCount;
  double get fps => _fps;

  void recordLatency(String engineName, int latencyMs) {
    _latencies[engineName] = latencyMs;
    notifyListeners();
  }

  void incrementDroppedFrames() {
    _droppedFrames++;
    notifyListeners();
  }

  void incrementCapturedFrames() {
    _capturedFrames++;
    notifyListeners();
  }

  void updateQueueDepth(int depth) {
    _queueDepth = depth;
    notifyListeners();
  }

  void incrementRetryCount() {
    _retryCount++;
    notifyListeners();
  }

  void updateFps(double newFps) {
    _fps = newFps;
    notifyListeners();
  }

  void clearMetrics() {
    _latencies.clear();
    _droppedFrames = 0;
    _capturedFrames = 0;
    _queueDepth = 0;
    _retryCount = 0;
    _fps = 0.0;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

class DiagnosticLog {
  final DateTime timestamp;
  final String source;
  final String message;
  final String? jsonPayload;
  final String? stackTrace;
  final bool isError;

  DiagnosticLog({
    required this.timestamp,
    required this.source,
    required this.message,
    this.jsonPayload,
    this.stackTrace,
    this.isError = false,
  });
}

class TelemetryService extends ChangeNotifier {
  final Map<String, int> _latencies = {};
  final List<DiagnosticLog> _logs = [];

  int _droppedFrames = 0;
  int _capturedFrames = 0;
  int _queueDepth = 0;
  int _retryCount = 0;
  double _fps = 0.0;

  Map<String, int> get latencies => _latencies;
  List<DiagnosticLog> get logs => _logs;
  int get droppedFrames => _droppedFrames;
  int get capturedFrames => _capturedFrames;
  int get queueDepth => _queueDepth;
  int get retryCount => _retryCount;
  double get fps => _fps;

  void addDiagnosticLog(String source, String message, {String? jsonPayload, String? stackTrace, bool isError = false}) {
    _logs.insert(0, DiagnosticLog(
      timestamp: DateTime.now(),
      source: source,
      message: message,
      jsonPayload: jsonPayload,
      stackTrace: stackTrace,
      isError: isError,
    ));
    if (_logs.length > 100) {
      _logs.removeLast(); // Keep recent 100
    }
    notifyListeners();
  }

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

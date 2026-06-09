import 'dart:async';
import 'package:flutter/foundation.dart';

class LocationService extends ChangeNotifier {
  bool _isRunning = false;
  double? _latitude;
  double? _longitude;
  Timer? _timer;

  bool get isRunning => _isRunning;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  /// Start location updates. This stub simulates GPS coordinates.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _timer?.cancel();
    // Provide an initial coordinate and then jitter it
    _latitude = 37.4219999;
    _longitude = -122.0840575;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Small random jitter
      _latitude = (_latitude ?? 0) + (0.0001 * (1 - 2 * (DateTime.now().millisecondsSinceEpoch % 2)));
      _longitude = (_longitude ?? 0) + (0.0001 * (1 - 2 * ((DateTime.now().millisecondsSinceEpoch + 1) % 2)));
      notifyListeners();
    });
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

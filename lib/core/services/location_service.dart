import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

class LocationService extends ChangeNotifier {
  bool _isRunning = false;
  double? _latitude;
  double? _longitude;
  String? _city;
  Timer? _timer;

  bool get isRunning => _isRunning;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get city => _city;

  /// Start location updates. This stub simulates GPS coordinates.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _timer?.cancel();
    // Provide an initial coordinate and then jitter it
    _latitude = 17.3850; // default to Hyderabad based on user req
    _longitude = 78.4867;
    await _updateCity();
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      // Small random jitter
      _latitude = (_latitude ?? 0) + (0.0001 * (1 - 2 * (DateTime.now().millisecondsSinceEpoch % 2)));
      _longitude = (_longitude ?? 0) + (0.0001 * (1 - 2 * ((DateTime.now().millisecondsSinceEpoch + 1) % 2)));
      await _updateCity();
      notifyListeners();
    });
  }

  Future<void> _updateCity() async {
    if (_latitude != null && _longitude != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
        if (placemarks.isNotEmpty) {
          _city = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? 'Unknown City';
        }
      } catch (e) {
        // Geocoding failed
        _city = 'Unknown City';
      }
    }
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

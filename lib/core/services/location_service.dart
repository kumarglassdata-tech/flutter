import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  bool _isRunning = false;
  double? _latitude;
  double? _longitude;
  String? _city;
  String? _country;
  StreamSubscription<Position>? _positionSubscription;

  bool get isRunning => _isRunning;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get city => _city;
  String? get country => _country;

  Future<void> start() async {
    if (_isRunning) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return;
    }

    _isRunning = true;
    
    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;
      await _updateCity();
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting initial location: $e');
    }

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 5),
    );
    
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) async {
        if (position != null) {
          _latitude = position.latitude;
          _longitude = position.longitude;
          await _updateCity();
          notifyListeners();
        }
      }
    );
  }

  Future<void> _updateCity() async {
    if (_latitude != null && _longitude != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
        if (placemarks.isNotEmpty) {
          _city = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? 'Unknown City';
          _country = placemarks.first.country ?? 'Unknown Country';
        }
      } catch (e) {
        // Geocoding failed
        _city = 'Unknown City';
        _country = 'Unknown Country';
      }
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

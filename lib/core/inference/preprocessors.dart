import 'dart:typed_data';
import 'dart:convert';

/// Image preprocessing placeholder: resize/normalize as required by model.
List<double> preprocessImage(Uint8List bytes, {int targetW = 224, int targetH = 224}) {
  // TODO: implement real image decoding + resize + normalization
  return List<double>.filled(targetW * targetH * 3, 0.0);
}

// Compute entry point must be a top-level function that accepts a single
// sendable argument. We pass a JSON-like map with base64-encoded bytes.
Map<String, dynamic> _preprocessImageEntry(Map<String, dynamic> args) {
  final bytes = base64Decode(args['bytes'] as String);
  final w = args['w'] as int? ?? 224;
  final h = args['h'] as int? ?? 224;
  final features = preprocessImage(Uint8List.fromList(bytes), targetW: w, targetH: h);
  return {'len': features.length};
}

Map<String, dynamic> preprocessImageEntryForCompute(Uint8List bytes, {int targetW = 224, int targetH = 224}) {
  return _preprocessImageEntry({'bytes': base64Encode(bytes), 'w': targetW, 'h': targetH});
}

/// Audio preprocessing placeholder: compute MFCC or spectrogram features.
List<double> preprocessAudio(Uint8List pcmBytes, {int sampleRate = 16000}) {
  // TODO: implement audio framing and MFCC extraction
  return List<double>.filled(128, 0.0);
}

/// GPS preprocessing placeholder: normalize lat/lon or compute relative features.
Map<String, double> preprocessGps(double? lat, double? lon) {
  return {
    'latitude': lat ?? 0.0,
    'longitude': lon ?? 0.0,
  };
}

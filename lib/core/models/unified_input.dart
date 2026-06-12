import 'dart:typed_data';

class VideoFrame {
  final Uint8List bytes;
  final int timestamp;
  final int width;
  final int height;

  const VideoFrame({required this.bytes, this.timestamp = 0, this.width = 0, this.height = 0});
}

class AudioChunk {
  final List<double> samples;
  final int timestamp;

  const AudioChunk(this.samples, {this.timestamp = 0});
}

class LocationData {
  final double latitude;
  final double longitude;
  final int timestamp;

  const LocationData({required this.latitude, required this.longitude, this.timestamp = 0});
}

enum InputSource {
  META,
  PHONE,
  WEBCAM,
  UPLOAD,
  MOCK,
}

class UnifiedInput {
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  final double? latitude;
  final double? longitude;
  final InputSource source;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const UnifiedInput({
    this.imageBytes,
    this.audioBytes,
    this.latitude,
    this.longitude,
    required this.source,
    required this.timestamp,
    this.metadata = const {},
  });
}

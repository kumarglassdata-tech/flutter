import 'dart:typed_data';

enum MediaSource { meta, phone, web, mock }

class VideoFrame {
  final Uint8List bytes;
  final int width;
  final int height;

  VideoFrame({required this.bytes, required this.width, required this.height});
}

class AudioChunk {
  final List<double> samples;

  AudioChunk(this.samples);
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({required this.latitude, required this.longitude});
}

class UnifiedInput {
  final VideoFrame? videoFrame;
  final AudioChunk? audioChunk;
  final LocationData? location;
  final MediaSource source;
  final int timestamp;
  final Map<String, dynamic>? mediaMetadata;

  UnifiedInput({
    this.videoFrame,
    this.audioChunk,
    this.location,
    required this.source,
    required this.timestamp,
    this.mediaMetadata,
  });
}

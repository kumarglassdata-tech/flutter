import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/services/audio_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';
import 'video_decoder_stub.dart'
    if (dart.library.html) 'video_decoder_web.dart';

class VideoUploadSourceAdapter implements SourceAdapter {
  final AudioService _audioService;
  final LocationService _locationService;

  final _videoController = StreamController<VideoFrame>.broadcast();
  final _audioController = StreamController<AudioChunk>.broadcast();
  final _locationController = StreamController<LocationData>.broadcast();
  final _healthController = StreamController<SourceHealth>.broadcast();

  bool _isActive = false;
  Timer? _timer;
  Timer? _healthTimer;

  Uint8List? _uploadedBytes;
  String? _fileName;
  bool _isImage = true;
  final _videoDecoder = VideoDecoder();

  VideoUploadSourceAdapter({
    required AudioService audio,
    required LocationService location,
  })  : _audioService = audio,
        _locationService = location;

  Uint8List? get uploadedBytes => _uploadedBytes;
  String? get fileName => _fileName;
  bool get isImage => _isImage;

  void setUploadedFile(Uint8List bytes, String name, bool isImage) {
    _uploadedBytes = bytes;
    _fileName = name;
    _isImage = isImage;

    if (!_isImage) {
      _videoDecoder.loadVideo(bytes, fileName: name).then((_) {
        if (_isActive && _uploadedBytes != null) {
          _emitFrame();
        }
      });
    } else {
      if (_isActive && _uploadedBytes != null) {
        _emitFrame();
      }
    }
  }

  @override
  Stream<VideoFrame> get videoStream => _videoController.stream;

  @override
  Stream<AudioChunk> get audioStream => _audioController.stream;

  @override
  Stream<LocationData> get locationStream => _locationController.stream;

  @override
  Stream<SourceHealth> get healthStream => _healthController.stream;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    // Start local audio & location services so we get real-time device inputs
    await _audioService.start();
    await _locationService.start();

    _audioService.addListener(_onAudioChanged);
    _locationService.addListener(_onLocationChanged);

    if (!_isImage && _uploadedBytes != null) {
      await _videoDecoder.loadVideo(_uploadedBytes!, fileName: _fileName);
    }

    // Stream frames periodically (every 3 seconds)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _emitFrame();
    });

    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _healthController.add(SourceHealth(
        status: SourceHealthStatus.healthy,
        message: _fileName != null ? 'Streaming from file: $_fileName' : 'Waiting for file upload',
      ));
    });

    _healthController.add(SourceHealth(
      status: SourceHealthStatus.healthy,
      message: _fileName != null ? 'Video Ingestion Source Started: $_fileName' : 'Video Ingestion Source Started (No File)',
    ));

    // Emit initial frame immediately if we already have file bytes
    _emitFrame();
  }

  Future<void> _emitFrame() async {
    if (!_isActive) return;

    if (_uploadedBytes != null) {
      if (_isImage) {
        _videoController.add(VideoFrame(
          bytes: _uploadedBytes!,
          width: 0,
          height: 0,
        ));
      } else {
        final frameBytes = await _videoDecoder.getNextFrame();
        if (frameBytes != null) {
          _videoController.add(VideoFrame(
            bytes: frameBytes,
            width: 0,
            height: 0,
          ));
        } else {
          // Generate a generic dark gray JPEG image dynamically for video fallbacks
          try {
            final image = img.Image(width: 128, height: 128);
            img.fill(image, color: img.ColorRgb8(40, 40, 40));
            final placeholderBytes = Uint8List.fromList(img.encodeJpg(image));
            _videoController.add(VideoFrame(
              bytes: placeholderBytes,
              width: 128,
              height: 128,
            ));
          } catch (_) {
            _videoController.add(VideoFrame(
              bytes: Uint8List.fromList([0, 1, 2, 3]),
              width: 0,
              height: 0,
            ));
          }
        }
      }
    } else {
      // Dynamic dark gray fallback JPEG
      try {
        final image = img.Image(width: 128, height: 128);
        img.fill(image, color: img.ColorRgb8(40, 40, 40));
        final placeholderBytes = Uint8List.fromList(img.encodeJpg(image));
        _videoController.add(VideoFrame(
          bytes: placeholderBytes,
          width: 128,
          height: 128,
        ));
      } catch (_) {
        _videoController.add(VideoFrame(
          bytes: Uint8List.fromList([0, 1, 2, 3]),
          width: 0,
          height: 0,
        ));
      }
    }
  }

  void _onAudioChanged() {
    _audioController.add(AudioChunk([_audioService.level]));
  }

  void _onLocationChanged() {
    if (_locationService.latitude != null && _locationService.longitude != null) {
      _locationController.add(LocationData(
        latitude: _locationService.latitude!,
        longitude: _locationService.longitude!,
      ));
    }
  }

  @override
  Future<void> stop() async {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
    _healthTimer?.cancel();
    _healthTimer = null;

    _audioService.removeListener(_onAudioChanged);
    _locationService.removeListener(_onLocationChanged);

    await _audioService.stop();
    await _locationService.stop();
    _videoDecoder.dispose();

    _healthController.add(const SourceHealth(
      status: SourceHealthStatus.disconnected,
      message: 'Video ingestion source stopped',
    ));
  }

  void dispose() {
    stop();
    _videoDecoder.dispose();
    _videoController.close();
    _audioController.close();
    _locationController.close();
    _healthController.close();
  }
}

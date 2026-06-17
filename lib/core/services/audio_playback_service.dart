import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
class AudioPlaybackService {
  // FlutterPcmSound has no player instance needed
  bool _isPlaying = false;
  Completer<void>? _startCompleter;

  Future<void> init() async {
    // Initialization happens in startStream
  }

  Future<void> startStream() async {
    if (_isPlaying) return;
    
    if (_startCompleter != null) {
      await _startCompleter!.future;
      return;
    }
    
    _startCompleter = Completer<void>();
    try {
      _isPlaying = true;
      FlutterPcmSound.start();
    } catch (e) {
      print("[AudioPlaybackService] Failed to start stream: $e");
    } finally {
      if (!_startCompleter!.isCompleted) {
        _startCompleter!.complete();
      }
      _startCompleter = null;
    }
  }

  Future<void> feedChunk(Uint8List pcmChunk) async {
    if (!_isPlaying) {
      await startStream();
    }
    if (!_isPlaying) return; // Prevent NullPointerException
    
    try {
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(pcmChunk.buffer.asInt16List()));
    } catch (e) {
      print("[AudioPlaybackService] Failed to feed audio chunk: $e");
    }
  }

  Future<void> stopStream() async {
    if (!_isPlaying) return;
    try {
      _isPlaying = false;
    } catch (e) {
      print("[AudioPlaybackService] Failed to stop stream: $e");
    }
  }

  Future<void> dispose() async {
    await stopStream();
  }
}

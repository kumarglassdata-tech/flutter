import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class AudioPlaybackService {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  Completer<void>? _startCompleter;

  Future<void> init() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
  }

  Future<void> startStream() async {
    if (_isPlaying || _player == null) return;
    
    if (_startCompleter != null) {
      await _startCompleter!.future;
      return;
    }
    
    _startCompleter = Completer<void>();
    try {
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
        interleaved: false,
      );
      _isPlaying = true;
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
      await _player!.feedFromStream(pcmChunk);
    } catch (e) {
      print("[AudioPlaybackService] Failed to feed audio chunk: $e");
    }
  }

  Future<void> stopStream() async {
    if (!_isPlaying || _player == null) return;
    try {
      await _player!.stopPlayer();
      _isPlaying = false;
    } catch (e) {
      print("[AudioPlaybackService] Failed to stop stream: $e");
    }
  }

  Future<void> dispose() async {
    await stopStream();
    await _player?.closePlayer();
    _player = null;
  }
}

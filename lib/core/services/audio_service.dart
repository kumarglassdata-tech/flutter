import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService extends ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRunning = false;
  double _level = 0.0;
  Timer? _levelTimer;
  String? _currentFilePath;

  bool get isRunning => _isRunning;
  double get level => _level;

  Future<void> start() async {
    if (_isRunning) return;
    
    if (await _audioRecorder.hasPermission()) {
      _isRunning = true;
      final tempDir = await getTemporaryDirectory();
      _currentFilePath = '${tempDir.path}/myna_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentFilePath!,
      );

      _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        if (await _audioRecorder.isRecording()) {
          final amplitude = await _audioRecorder.getAmplitude();
          // Normalize amplitude (usually from -160 to 0) to 0.0 - 1.0
          // E.g., -50 is typical speaking, -160 is silence
          final normalized = (amplitude.current + 160) / 160.0;
          _level = normalized.clamp(0.0, 1.0);
          notifyListeners();
        }
      });
      
      notifyListeners();
    } else {
      debugPrint('Audio recording permission denied.');
    }
  }

  Future<Uint8List?> stopAndGetBytes() async {
    if (!_isRunning) return null;
    
    _isRunning = false;
    _levelTimer?.cancel();
    _levelTimer = null;
    _level = 0.0;
    
    final path = await _audioRecorder.stop();
    notifyListeners();

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Optionally clean up the file
        await file.delete();
        return bytes;
      }
    }
    return null;
  }

  Future<void> stop() async {
    await stopAndGetBytes();
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

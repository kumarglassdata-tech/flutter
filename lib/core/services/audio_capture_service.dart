import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

// Top-level function for Isolate computation
Future<String?> _encodeAudioToBase64(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    // Delete file immediately to prevent leaks
    await file.delete();
    return base64Encode(bytes);
  } catch (e) {
    print('[AudioCaptureService] Isolate encode failed: $e');
    return null;
  }
}

class AudioCaptureService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  
  Future<void> init() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      print('[AudioCaptureService] Microphone permission denied.');
    }
  }

  Future<void> startRecording(String tempFilePath) async {
    if (_isRecording) return;
    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: tempFilePath,
      );
      _isRecording = true;
    } catch (e) {
      print('[AudioCaptureService] Failed to start recording: $e');
    }
  }

  Future<String?> stopAndEncode() async {
    if (!_isRecording) return null;
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      if (path != null) {
        // Run Base64 encoding and file deletion on a background isolate
        return await compute(_encodeAudioToBase64, path);
      }
    } catch (e) {
      print('[AudioCaptureService] Failed to stop recording: $e');
    }
    return null;
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}

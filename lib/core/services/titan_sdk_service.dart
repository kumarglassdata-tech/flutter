import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TitanSdkService {
  static const MethodChannel _channel = MethodChannel('smart_myna/titan_sdk');
  static const EventChannel _audioChannel = EventChannel('smart_myna/titan_audio_stream');

  /// Streams PCM audio directly from the Titan Glasses
  Stream<Uint8List> get audioStream {
    return _audioChannel
        .receiveBroadcastStream()
        .map((event) => event as Uint8List);
  }

  bool get supportsNativeSdk => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isSdkAvailable() async {
    return supportsNativeSdk;
  }

  Future<bool> connect(String deviceAddress) async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('connect', {
            'deviceAddress': deviceAddress,
          })) ??
          false;
    } catch (e) {
      debugPrint("TitanSdkService.connect Error: $e");
      return false;
    }
  }

  Future<bool> capturePhoto() async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('capturePhoto')) ?? false;
    } catch (e) {
      debugPrint("TitanSdkService.capturePhoto Error: $e");
      return false;
    }
  }

  Future<bool> startAudio() async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('startAudio')) ?? false;
    } catch (e) {
      debugPrint("TitanSdkService.startAudio Error: $e");
      return false;
    }
  }

  Future<bool> stopAudio() async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('stopAudio')) ?? false;
    } catch (e) {
      debugPrint("TitanSdkService.stopAudio Error: $e");
      return false;
    }
  }
}

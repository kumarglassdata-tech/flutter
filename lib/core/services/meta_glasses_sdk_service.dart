import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MetaGlassesSdkService {
  const MetaGlassesSdkService();

  static const MethodChannel _channel = MethodChannel('smart_myna/meta_sdk');
  static const EventChannel _streamChannel = EventChannel('smart_myna/meta_stream');

  Stream<Uint8List> get videoFrameStream {
    return _streamChannel
        .receiveBroadcastStream()
        .map((event) => event as Uint8List);
  }

  bool get supportsNativeSdk => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isSdkAvailable() async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('isSdkAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getMetaDevices() async {
    if (!supportsNativeSdk) return const [];
    try {
      final List<dynamic>? devices = await _channel.invokeMethod<List<dynamic>>('getMetaDevices');
      if (devices == null) return const [];
      return devices.map((d) => Map<String, String>.from(d as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> register() async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('register')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect(String deviceAddress, {bool useMock = false, bool isMeta = false}) async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('connect', {
            'deviceAddress': deviceAddress,
            'useMock': useMock,
            'isMeta': isMeta,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startVideoStream({bool useMock = false}) async {
    if (!supportsNativeSdk) return false;
    try {
      return (await _channel.invokeMethod<bool>('startVideoStream', {
            'useMock': useMock,
          })) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopVideoStream() async {
    if (!supportsNativeSdk) return;
    try {
      await _channel.invokeMethod<void>('stopVideoStream');
    } catch (_) {
      // Best-effort shutdown.
    }
  }
}

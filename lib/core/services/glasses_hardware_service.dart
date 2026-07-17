import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Models events emitted by the Native Glasses SDK Wrapper
abstract class GlassesHardwareEvent {}

class DeviceFoundEvent extends GlassesHardwareEvent {
  final String name;
  final String address;
  final int rssi;
  DeviceFoundEvent(this.name, this.address, this.rssi);
}

class ConnectionStateEvent extends GlassesHardwareEvent {
  final bool isConnected;
  final String address;
  ConnectionStateEvent(this.isConnected, this.address);
}

class ServicesDiscoveredEvent extends GlassesHardwareEvent {}
class BatteryLevelEvent extends GlassesHardwareEvent {
  final int level;
  BatteryLevelEvent(this.level);
}

class AudioDataEvent extends GlassesHardwareEvent {
  final Uint8List pcmData;
  AudioDataEvent(this.pcmData);
}

class PhotoChunkEvent extends GlassesHardwareEvent {
  final Uint8List bytes;
  PhotoChunkEvent(this.bytes);
}

class WearStateEvent extends GlassesHardwareEvent {
  final bool isWearing;
  WearStateEvent(this.isWearing);
}

class VideoDownloadProgressEvent extends GlassesHardwareEvent {
  final double progress; // 0.0 – 1.0
  VideoDownloadProgressEvent(this.progress);
}

class VideoFileDownloadedEvent extends GlassesHardwareEvent {
  final String filePath;
  VideoFileDownloadedEvent(this.filePath);
}

class VideoDownloadErrorEvent extends GlassesHardwareEvent {
  final String error;
  VideoDownloadErrorEvent(this.error);
}

/// Communicates with the Native Kotlin `GlassesManager` via MethodChannels
class GlassesHardwareService {
  static const MethodChannel _commandChannel = MethodChannel('smart_myna/glasses_commands');
  static const EventChannel _eventChannel = EventChannel('smart_myna/glasses_events');

  final StreamController<GlassesHardwareEvent> _eventController = StreamController.broadcast();
  Stream<GlassesHardwareEvent> get events => _eventController.stream;

  GlassesHardwareService() {
    if (!kIsWeb) {
      _eventChannel.receiveBroadcastStream().listen(_onNativeEvent);
    }
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    
    final map = Map<String, dynamic>.from(event);
    final type = map['type'] as String?;
    
    switch (type) {
      case 'DeviceFound':
        _eventController.add(DeviceFoundEvent(
          map['name'] as String? ?? 'Unknown', 
          map['address'] as String? ?? '', 
          map['rssi'] as int? ?? 0
        ));
        break;
      case 'ConnectionStateChanged':
        _eventController.add(ConnectionStateEvent(
          map['isConnected'] as bool? ?? false, 
          map['address'] as String? ?? ''
        ));
        break;
      case 'BatteryLevel':
        _eventController.add(BatteryLevelEvent(map['level'] as int? ?? 0));
        break;
      case 'WearStateChanged':
        _eventController.add(WearStateEvent(map['isWearing'] as bool? ?? false));
        break;
      case 'ServicesDiscovered':
        _eventController.add(ServicesDiscoveredEvent());
        break;
      case 'AudioDataReceived':
        if (map['pcmData'] is Uint8List) {
          _eventController.add(AudioDataEvent(map['pcmData'] as Uint8List));
        }
        break;
      case 'PhotoChunkReceived':
        if (map['bytes'] is Uint8List) {
          _eventController.add(PhotoChunkEvent(map['bytes'] as Uint8List));
        }
        break;
      case 'VideoDownloadProgress':
        _eventController.add(VideoDownloadProgressEvent(
          (map['progress'] as num? ?? 0.0).toDouble()
        ));
        break;
      case 'VideoFileDownloaded':
        _eventController.add(VideoFileDownloadedEvent(map['filePath'] as String? ?? ''));
        break;
      case 'VideoDownloadError':
        _eventController.add(VideoDownloadErrorEvent(map['error'] as String? ?? 'Unknown error'));
        break;
      // Map other events here...
    }
  }

  Future<void> startScan() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('startScan');
  }

  Future<void> stopScan() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('stopScan');
  }

  Future<void> connect(String macAddress) async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('connect', {'macAddress': macAddress});
  }

  Future<void> disconnect() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('disconnect');
  }

  Future<void> enableDataServices() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('enableDataServices');
  }

  Future<void> setVolume(double level) async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('setVolume', {'level': level});
  }
  
  Future<void> syncBattery() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('syncBattery');
  }

  Future<void> checkWearState() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('checkWearState');
  }

  Future<void> capturePhoto() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('capturePhoto');
  }

  Future<void> captureThumbnail() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('captureThumbnail');
  }
  
  Future<void> startVideoRecording() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('startVideoRecording');
  }

  Future<void> stopVideoRecording() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('stopVideoRecording');
  }

  Future<void> importVideoAlbum() async {
    if (kIsWeb) return;
    await _commandChannel.invokeMethod('importVideoAlbum');
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class TestContextWebsocketClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _status = 'Disconnected';
  final List<String> _logs = [];
  String? _lastUrl;

  bool get isConnected => _isConnected;
  String get status => _status;
  List<String> get logs => List.unmodifiable(_logs);

  void _addLog(String msg) {
    debugPrint('[TestContextWebsocket] $msg');
    final time = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    _logs.insert(0, '[$time] $msg');
    if (_logs.length > 100) _logs.removeLast(); // Keep only last 100 logs
    notifyListeners();
  }

  Future<void> connect(String url) async {
    if (_isConnected) return;
    _lastUrl = url;
    try {
      _addLog('Connecting to $url...');
      // Using IOWebSocketChannel to provide a ping interval so the server doesn't drop us!
      final ws = await WebSocket.connect(url);
      ws.pingInterval = const Duration(seconds: 2);
      _channel = IOWebSocketChannel(ws);
      
      _isConnected = true;
      _status = 'Connected';
      _addLog('Connected!');
      notifyListeners();

      _channel?.stream.listen(
        (message) {
          _addLog('Received: $message');
        },
        onDone: () {
          _isConnected = false;
          _status = 'Disconnected';
          _addLog('Connection closed by server.');
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          _status = 'Error';
          _addLog('WebSocket error: $error');
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      _status = 'Failed to connect';
      _addLog('Exception during connect: $e');
      notifyListeners();
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _status = 'Disconnected';
    _addLog('Disconnected by user.');
    notifyListeners();
  }

  void sendFrameWithMetadata(Uint8List imageBytes, double lat, double lon) {
    if (!_isConnected || _channel == null) {
      _addLog('Warning: Cannot send frame, not connected.');
      return;
    }
    
    // 1. Send the JSON Metadata as a text frame
    final metadataPayload = jsonEncode({
      'gps_coordinates': {
        'lat': lat,
        'lon': lon,
      },
      'temperature_c': 38.5,
      'facing_mode': 'environment'
    });
    
    _channel?.sink.add(metadataPayload);
    _addLog('Sent Metadata: $metadataPayload');
    
    // 2. Send the JPEG bytes as a binary frame
    _channel?.sink.add(imageBytes);
    _addLog('Sent Video Frame (JPEG): ${imageBytes.lengthInBytes} bytes');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';

class AudioStreamManager {
  WebSocketChannel? _channel;
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  // Stream controllers to notify UI of status or transcripts
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  Future<void> init() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
  }

  final List<Uint8List> _audioQueue = [];
  bool _isProcessingQueue = false;
  bool _isStopping = false;

  void _enqueueAudio(Uint8List chunk) {
    if (!_isPlaying || _isStopping) return;
    _audioQueue.add(chunk);
    _processAudioQueue();
  }

  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    try {
      while (_audioQueue.isNotEmpty && _isPlaying) {
        final chunk = _audioQueue.removeAt(0);
        int chunkSize = 4096;
        for (int i = 0; i < chunk.length; i += chunkSize) {
          if (!_isPlaying) break;
          int end = i + chunkSize;
          if (end > chunk.length) end = chunk.length;
          try {
            await _player!.feedFromStream(chunk.sublist(i, end));
          } catch (e) {
            break;
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  void connect(String url) {
    // Connect to WebSocket e.g. ws://127.0.0.1:8002
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (message) async {
        if (message is List<int> || message is Uint8List) {
          if (_player != null) {
            if (!_isPlaying) {
              await _startStream();
            }
            if (!_isPlaying) return; // CRITICAL: Stop crash if stream failed to start!
            
            try {
              Uint8List pcmChunk = Uint8List.fromList(message as List<int>);
              if (pcmChunk.isNotEmpty) {
                 // Ensure even length for 16-bit PCM to prevent SIGSEGV
                 if (pcmChunk.length % 2 != 0) {
                   pcmChunk = pcmChunk.sublist(0, pcmChunk.length - 1);
                 }
                 _enqueueAudio(pcmChunk);
              }
            } catch (e) {
              print("[APP ERROR]: Failed to enqueue audio chunk: $e");
            }
          }
        } else if (message is String) {
          // 2. Handle Text Control JSON
          try {
            print("[WS DEBUG]: $message");
            final Map<String, dynamic> data = jsonDecode(message);
            final String? type = data['type'];
            
            switch (type) {
              case 'audio_start':
                print("[APP]: Assistant started speaking.");
                await _startStream();
                break;

              case 'audio_end':
                print("[APP]: Assistant finished speaking.");
                await _stopStream();
                break;

              case 'transcript':
                final String text = data['text'] ?? '';
                _transcriptController.add(text);
                break;

              case 'status':
                _statusController.add(data);
                break;
            }
          } catch (e) {
            print("[APP ERROR]: Failed parsing control message: $e");
          }
        }
      },
      onError: (err) {
        print("[APP ERROR]: Connection closed with error: $err");
      },
      onDone: () {
        print("[APP]: WebSocket connection closed.");
      },
    );
  }

  // Send telemetry payload to trigger proactive dialogue FSM
  void sendTelemetry(Map<String, dynamic> telemetryPayload) {
    if (_channel != null) {
      final message = jsonEncode({
        "type": "telemetry",
        "payload": telemetryPayload,
      });
      _channel!.sink.add(message);
    }
  }

  // Interruption/Barge-in: Tell server to halt active speech generation
  void triggerBargeIn() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": "user_interruption"}));
      _stopStream();
    }
  }

  Completer<void>? _startCompleter;

  Future<void> _startStream() async {
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
      print("[APP ERROR]: Failed to start stream: $e");
    } finally {
      if (!_startCompleter!.isCompleted) {
        _startCompleter!.complete();
      }
      _startCompleter = null;
    }
  }

  Future<void> _stopStream() async {
    if (!_isPlaying || _player == null || _isStopping) return;
    _isStopping = true;
    _isPlaying = false;
    _audioQueue.clear();
    
    // Wait for the processing loop to gracefully exit
    while (_isProcessingQueue) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    try {
      await _player!.stopPlayer();
    } catch (e) {
      print("[APP ERROR]: Failed to stop stream: $e");
    } finally {
      _isStopping = false;
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    if (_player != null) {
      await _player!.stopPlayer();
      await _player!.closePlayer();
      _player = null;
    }
    await _micSubscription?.cancel();
    _micSubscription = null;
    _isPlaying = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _audioRecorder.dispose();
    await _transcriptController.close();
    await _statusController.close();
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      triggerBargeIn(); // Stop any active playback
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({"type": "start_of_speech"}));
      }
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      
      _micSubscription = stream.listen((data) {
        if (_channel != null) {
          _channel!.sink.add(data);
        }
      });
    }
  }

  Future<void> stopRecording() async {
    await _audioRecorder.stop();
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": "end_of_speech"}));
    }
  }
}

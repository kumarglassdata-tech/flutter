import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';

// RMS amplitude threshold — tune for smart glasses mic sensitivity
// 0.01 = very sensitive, 0.05 = moderate, 0.10 = only loud speech
const double _kSpeechThreshold = 0.02;
const Duration _kSilenceTimeout = Duration(milliseconds: 800);

class AudioStreamManager {
  WebSocketChannel? _channel;
  bool _isPlaying = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  // VAD state
  bool _vadActive = false;
  bool _isSpeaking = false;
  Timer? _silenceTimer;

  // Playback queue
  final List<Uint8List> _audioQueue = [];
  bool _isProcessingQueue = false;
  bool _isStopping = false;

  // WebSocket reconnect
  bool _intentionalDisconnect = false;
  String? _currentUrl;
  Timer? _reconnectTimer;

  // PCM start lock
  Completer<void>? _startCompleter;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  bool get isVadActive => _vadActive;
  bool get isRecording => _micSubscription != null;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
    // The Interaction Engine backend streams 24kHz PCM-16 TTS
    await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
  }

  // ---------------------------------------------------------------------------
  // VAD — continuous hands-free listening
  // ---------------------------------------------------------------------------

  Future<void> startVad() async {
    if (_vadActive) return;
    if (!await _audioRecorder.hasPermission()) {
      debugPrint('[AudioStreamManager] Mic permission denied.');
      return;
    }
    _vadActive = true;
    _isSpeaking = false;

    // Ensure any stuck native recording session is killed before starting a new one
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('[AudioStreamManager] Non-fatal error stopping previous recorder: $e');
    }

    final stream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _micSubscription = stream.listen((Uint8List chunk) {
      if (!_vadActive) return;
      
      // PERMANENT ECHO FIX: Completely drop microphone frames while the AI is speaking.
      // This guarantees the AI can never hear itself, never trigger false VAD, 
      // and never cut itself off mid-sentence.
      if (_isPlaying) return;

      final rms = _calculateRms(chunk);

      if (rms >= _kSpeechThreshold) {
        _silenceTimer?.cancel();
        _silenceTimer = null;

        if (!_isSpeaking) {
          _isSpeaking = true;
          debugPrint('[VAD] Speech started (rms=${rms.toStringAsFixed(4)})');
          _safeSinkAdd(jsonEncode({'type': 'start_of_speech'}));
        }
        // Stream chunk to server while speaking
        _safeSinkAdd(chunk);
      } else {
        // Keep streaming during natural brief pauses so the server gets context
        if (_isSpeaking) {
          _safeSinkAdd(chunk);
          _silenceTimer ??= Timer(_kSilenceTimeout, () {
            if (_isSpeaking) {
              _isSpeaking = false;
              debugPrint('[VAD] Speech ended (silence timeout)');
              _safeSinkAdd(jsonEncode({'type': 'end_of_speech'}));
            }
            _silenceTimer = null;
          });
        }
      }
    }, onError: (err) {
      debugPrint('[AudioStreamManager] Mic stream error: $err. Restarting...');
      _vadActive = false;
      _micSubscription?.cancel();
      _micSubscription = null;
      Future.delayed(const Duration(seconds: 1), startVad);
    }, onDone: () {
      debugPrint('[AudioStreamManager] Mic stream closed unexpectedly. Restarting...');
      _vadActive = false;
      _micSubscription?.cancel();
      _micSubscription = null;
      Future.delayed(const Duration(seconds: 1), startVad);
    });
  }

  Future<void> stopVad() async {
    if (!_vadActive) return;
    _vadActive = false;
    _isSpeaking = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await _audioRecorder.stop();
    await _micSubscription?.cancel();
    _micSubscription = null;
    // do NOT send end_of_speech here — VAD stop is a system stop, not an utterance end
  }

  // ---------------------------------------------------------------------------
  // RMS calculation — 16-bit PCM little-endian, normalised 0.0–1.0
  // ---------------------------------------------------------------------------

  double _calculateRms(Uint8List data) {
    if (data.length < 2) return 0.0;
    double sumSq = 0.0;
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = (data[i + 1] << 8) | data[i];
      if (sample >= 32768) sample -= 65536; // sign extend
      final norm = sample / 32768.0;
      sumSq += norm * norm;
    }
    final sampleCount = data.length ~/ 2;
    return sqrt(sumSq / sampleCount);
  }

  // ---------------------------------------------------------------------------
  // Push-to-talk fallback (manual mic button)
  // ---------------------------------------------------------------------------

  Future<void> startRecording() async {
    if (isRecording || _vadActive) return;
    if (!await _audioRecorder.hasPermission()) {
      debugPrint('[AudioStreamManager] Mic permission denied.');
      return;
    }
    triggerBargeIn();
    _safeSinkAdd(jsonEncode({'type': 'start_of_speech'}));
    final stream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _micSubscription = stream.listen((data) => _safeSinkAdd(data));
  }

  Future<void> stopRecording() async {
    await _audioRecorder.stop();
    await _micSubscription?.cancel();
    _micSubscription = null;
    _safeSinkAdd(jsonEncode({'type': 'end_of_speech'}));
  }

  // ---------------------------------------------------------------------------
  // WebSocket connection
  // ---------------------------------------------------------------------------

  void connect(String url) {
    _intentionalDisconnect = false;
    _currentUrl = url;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (message) async {
          if (message is List<int> || message is Uint8List) {
            // Wait for any in-progress stop to clear before starting playback
            while (_isStopping) {
              await Future.delayed(const Duration(milliseconds: 5));
            }
            if (!_isPlaying) await _startStream();
            // Re-check after await — _startStream may have failed
            if (!_isPlaying) return;
            try {
              Uint8List pcmChunk = Uint8List.fromList(message as List<int>);
              if (pcmChunk.isNotEmpty) {
                if (pcmChunk.length % 2 != 0) {
                  pcmChunk = pcmChunk.sublist(0, pcmChunk.length - 1);
                }
                _enqueueAudio(pcmChunk);
              }
            } catch (e) {
              debugPrint('[AudioStreamManager] Failed to enqueue audio chunk: $e');
            }
          } else if (message is String) {
            try {
              final data = jsonDecode(message) as Map<String, dynamic>;
              switch (data['type'] as String?) {
                case 'audio_start':
                  await _startStream();
                  break;
                case 'audio_end':
                  await _stopStream();
                  break;
                case 'transcript':
                  _transcriptController.add(data['text'] as String? ?? '');
                  break;
                case 'status':
                  _statusController.add(data);
                  break;
              }
            } catch (e) {
              debugPrint('[AudioStreamManager] Failed parsing control message: $e');
            }
          }
        },
        onError: (err) {
          debugPrint('[AudioStreamManager] WS error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[AudioStreamManager] WS closed.');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[AudioStreamManager] Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_intentionalDisconnect && _currentUrl != null) {
        debugPrint('[AudioStreamManager] Reconnecting...');
        connect(_currentUrl!);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Telemetry & barge-in
  // ---------------------------------------------------------------------------

  void sendTelemetry(Map<String, dynamic> telemetryPayload) {
    _safeSinkAdd(jsonEncode({'type': 'telemetry', 'payload': telemetryPayload}));
  }

  void triggerBargeIn() {
    if (!_isPlaying) return;
    _safeSinkAdd(jsonEncode({'type': 'user_interruption'}));
  }

  void _safeSinkAdd(dynamic data) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(data);
    } catch (e) {
      debugPrint('[AudioStreamManager] sink.add error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PCM playback
  // ---------------------------------------------------------------------------

  void _enqueueAudio(Uint8List chunk) {
    if (_isStopping || !_isPlaying) return;
    _audioQueue.add(chunk);
    _processAudioQueue();
  }

  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    try {
      while (_audioQueue.isNotEmpty && _isPlaying) {
        final chunk = _audioQueue.removeAt(0);
        for (int i = 0; i < chunk.length; i += 4096) {
          if (!_isPlaying) break;
          final end = (i + 4096).clamp(0, chunk.length);
          try {
            await FlutterPcmSound.feed(
              PcmArrayInt16.fromList(chunk.sublist(i, end).buffer.asInt16List()),
            );
          } catch (e) {
            break;
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _startStream() async {
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
      _isPlaying = false;
      debugPrint('[AudioStreamManager] Failed to start PCM stream: $e');
    } finally {
      if (!_startCompleter!.isCompleted) _startCompleter!.complete();
      _startCompleter = null;
    }
  }

  Future<void> _stopStream() async {
    if (!_isPlaying || _isStopping) return;
    _isStopping = true;
    _isPlaying = false;
    _audioQueue.clear();
    while (_isProcessingQueue) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    try {
      await FlutterPcmSound.stop().timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[AudioStreamManager] Failed to stop PCM stream: $e');
    }
    _isStopping = false;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    await _micSubscription?.cancel();
    _micSubscription = null;
    _isPlaying = false;
  }

  Future<void> dispose() async {
    await stopVad();
    await disconnect();
    await _audioRecorder.dispose();
    await FlutterPcmSound.release();
    await _transcriptController.close();
    await _statusController.close();
  }
}

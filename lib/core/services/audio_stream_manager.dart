import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_silero_vad/flutter_silero_vad.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';

const Duration _kSilenceTimeout = Duration(milliseconds: 800);

class AudioStreamManager {
  WebSocketChannel? _channel;
  bool _isPlaying = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  // VAD state
  bool _vadActive = false;
  bool _isSpeaking = false;
  bool _waitingForMIISResponse = false;
  Timer? _silenceTimer;
  FlutterSileroVad? _vad;
  final List<int> _audioAccumulator = [];

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
  int _debugFrameCount = 0;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _isSpeakingController = StreamController<bool>.broadcast();
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;

  bool get isVadActive => _vadActive;
  bool get isRecording => _micSubscription != null;
  bool get isSpeaking => _isSpeaking;

  // Callback to fetch dynamic behavior context right before speech starts
  Map<String, dynamic> Function()? onSpeechStartContext;

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
    // The Interaction Engine backend streams 16kHz PCM-16 TTS
    await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);

    try {
      _vad = FlutterSileroVad();
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/silero_vad.onnx';
      
      final data = await rootBundle.load('assets/models/silero_vad.onnx');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      File(modelPath).writeAsBytesSync(bytes);
      
      await _vad!.initialize(
        modelPath: modelPath,
        sampleRate: 16000,
        frameSize: 32,
        threshold: 0.3,
        minSilenceDurationMs: 0,
        speechPadMs: 0,
      );
      debugPrint('[AudioStreamManager] Silero VAD initialized successfully');
    } catch (e) {
      debugPrint('[AudioStreamManager] Failed to initialize VAD: $e');
    }
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
    _waitingForMIISResponse = false;

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
      autoGain: true, // Dynamically boosts volume on quiet mics (like Redmi)
      echoCancel: true, // Hardware echo cancellation
      noiseSuppress: true, // Hardware noise suppression
    ));

    _micSubscription = stream.listen((Uint8List chunk) async {
      if (!_vadActive) return;
      
      // PERMANENT ECHO FIX: Completely drop microphone frames while the AI is speaking or waiting for MIIS.
      if (_isPlaying || _waitingForMIISResponse) {
         _audioAccumulator.clear();
         return;
      }

      // Copy to ensure 0-offset alignment and even length, preventing 'Offset must be a multiple of 2' RangeError
      final int alignedLen = chunk.length - (chunk.length % 2);
      final safeChunk = Uint8List(alignedLen);
      safeChunk.setRange(0, alignedLen, chunk);
      final int16List = safeChunk.buffer.asInt16List();

      // Apply 1x digital gain to fix quiet mic on Android devices
      for (int i = 0; i < int16List.length; i++) {
        int amplified = (int16List[i] * 1.0).round();
        if (amplified > 32767) amplified = 32767;
        if (amplified < -32768) amplified = -32768;
        int16List[i] = amplified;
      }

      _audioAccumulator.addAll(int16List);

      // Frame size 32ms at 16000Hz = 512 samples
      const int targetSamples = 512;

      while (_audioAccumulator.length >= targetSamples) {
        final frameSamples = _audioAccumulator.sublist(0, targetSamples);
        _audioAccumulator.removeRange(0, targetSamples);

        final float32List = Float32List(targetSamples);
        double maxAmplitude = 0.0;
        for (int i = 0; i < targetSamples; i++) {
          final val = frameSamples[i] / 32768.0;
          float32List[i] = val;
          if (val.abs() > maxAmplitude) maxAmplitude = val.abs();
        }

        _debugFrameCount++;
        if (_debugFrameCount >= 30) {
          debugPrint('[VAD] Mic chunk received. Max amplitude: ${maxAmplitude.toStringAsFixed(4)}');
          _debugFrameCount = 0;
        }

        bool isActive = false;
        if (_vad != null) {
          try {
            isActive = (await _vad!.predict(float32List)) ?? false;
          } catch (e) {
            debugPrint('[VAD] Prediction error: $e');
          }

          // Fallback: If the neural net is unsure but the volume is very loud, force it active
          // Note: Set to 0.1 because Redmi Note 9 Pro max speaking volume is only 0.14
          if (!isActive && maxAmplitude > 0.1) {
            isActive = true;
          }

          if (isActive) {
            _silenceTimer?.cancel();
            _silenceTimer = null;

            if (!_isSpeaking) {
              _isSpeaking = true;
              _isSpeakingController.add(true);
              debugPrint('[VAD] Speech started (Silero)');
              
              final startMessage = <String, dynamic>{'type': 'start_of_speech'};
              if (onSpeechStartContext != null) {
                final ctx = onSpeechStartContext!();
                if (ctx.isNotEmpty) {
                  startMessage['context'] = ctx;
                }
              }
              _safeSinkAdd(jsonEncode(startMessage));
            }
          } else {
            if (_isSpeaking) {
              _silenceTimer ??= Timer(_kSilenceTimeout, () {
                  _isSpeaking = false;
                  _waitingForMIISResponse = true;
                  
                  // SAFETY TIMEOUT: If backend completely fails to respond within 8 seconds, unlock the mic.
                  Timer(const Duration(seconds: 8), () {
                    if (_waitingForMIISResponse) {
                      debugPrint('[VAD] MIIS response timeout! Forcing mic unlock.');
                      _waitingForMIISResponse = false;
                    }
                  });
                  
                  _isSpeakingController.add(false);
                  debugPrint('[VAD] Speech ended (silence timeout), waiting for MIIS...');
                  _safeSinkAdd(jsonEncode({'type': 'end_of_speech'}));
                }
                _silenceTimer = null;
              });
            }
          }
        }
      }

      // Keep streaming while speaking
      if (_isSpeaking) {
        _safeSinkAdd(safeChunk);
      }
    }, onError: (err) {
      debugPrint('[AudioStreamManager] Mic stream error: $err.');
      _vadActive = false;
      _micSubscription?.cancel();
      _micSubscription = null;
      if (!_isPlaying) {
        Future.delayed(const Duration(milliseconds: 50), startVad);
      } else {
        debugPrint('[AudioStreamManager] Deferring mic restart until TTS finishes.');
      }
    }, onDone: () {
      debugPrint('[AudioStreamManager] Mic stream closed unexpectedly.');
      _vadActive = false;
      _micSubscription?.cancel();
      _micSubscription = null;
      if (!_isPlaying) {
        Future.delayed(const Duration(milliseconds: 50), startVad);
      } else {
        debugPrint('[AudioStreamManager] Deferring mic restart until TTS finishes.');
      }
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
  // Output WebSocket processingalk fallback (manual mic button)
  // ---------------------------------------------------------------------------

  Future<void> startRecording() async {
    if (isRecording || _vadActive) return;
    if (!await _audioRecorder.hasPermission()) {
      debugPrint('[AudioStreamManager] Mic permission denied.');
      return;
    }
    triggerBargeIn();
    
    final startMessage = <String, dynamic>{'type': 'start_of_speech'};
    if (onSpeechStartContext != null) {
      final ctx = onSpeechStartContext!();
      if (ctx.isNotEmpty) {
        startMessage['context'] = ctx;
      }
    }
    _safeSinkAdd(jsonEncode(startMessage));
    
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
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (message) async {
          if (message is List<int> || message is Uint8List) {
            debugPrint('[AudioStreamManager] Received binary audio chunk of size: ${(message as List).length} bytes');
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
              debugPrint('[AudioStreamManager] Received WS control: ${data['type']}');
              switch (data['type'] as String?) {
                case 'audio_start':
                  await _startStream();
                  break;
                case 'audio_end':
                  await _stopStream();
                  break;
                case 'transcript':
                  debugPrint('[AudioStreamManager] Backend Transcript: ${data['text']}');
                  _transcriptController.add(data['text'] as String? ?? '');
                  break;
                case 'status':
                  _waitingForMIISResponse = false;
                  debugPrint('[AudioStreamManager] Backend Status: ${data['status']}');
                  _statusController.add(data);
                  break;
                case 'toast':
                  debugPrint('[AudioStreamManager] Backend Toast: ${data['message']}');
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
    _waitingForMIISResponse = false;
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
    if (_channel == null || _channel!.closeCode != null) return;
    try {
      _channel!.sink.add(data);
    } catch (e) {
      if (e.toString().contains('Cannot add event after closing')) return;
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
          try {
            final int end = (i + 4096 < chunk.length) ? i + 4096 : chunk.length;
            final subChunk = chunk.sublist(i, end);
            final int subAlignedLen = subChunk.length - (subChunk.length % 2);
            final safeSubChunk = Uint8List(subAlignedLen);
            safeSubChunk.setRange(0, subAlignedLen, subChunk);
            
            await FlutterPcmSound.feed(
              PcmArrayInt16.fromList(safeSubChunk.buffer.asInt16List()),
            );
          } catch (e) {
            debugPrint("[AudioStreamManager] Failed to feed TTS chunk: $e");
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
    
    // Do NOT clear the audio queue here! `audio_end` arrives over the network 
    // instantly, but the audio takes time to physically play out of the speaker.
    // We must wait for the queue to completely finish before killing the engine.
    int timeoutCounter = 0;
    while ((_audioQueue.isNotEmpty || _isProcessingQueue) && timeoutCounter < 200) {
      await Future.delayed(const Duration(milliseconds: 20));
      timeoutCounter++;
    }


    try {
      await FlutterPcmSound.release();
      await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);
    } catch (e) {
      debugPrint('[AudioStreamManager] Failed to stop PCM stream: $e');
    }
    
    // ECHO FIX: The OS audio buffer (AudioTrack) holds ~500ms of audio that 
    // physically plays out of the speaker AFTER we stop feeding it. We MUST 
    // delay turning the microphone back on, otherwise the app hears its own echo!
    await Future.delayed(const Duration(milliseconds: 1000));
    
    _isPlaying = false;
    _isStopping = false;

    // Check if mic was dropped during playback and restart it
    if (!_vadActive && _micSubscription == null) {
      debugPrint('[AudioStreamManager] TTS finished. Resuming deferred mic stream...');
      Future.delayed(const Duration(milliseconds: 50), startVad);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    try {
      if (_channel != null) {
        await _channel!.sink.close().timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('[AudioStreamManager] Non-fatal error closing WS: $e');
    }
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

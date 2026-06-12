import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

import 'package:smartglass_flutter/core/services/audio_stream_manager.dart';

class InteractionClient {
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final bool fallbackToMock;
  AudioStreamManager? audioStreamManager;

  InteractionClient({
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
  })  : _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'InteractionSubsystem');

  void setAudioStreamManager(AudioStreamManager manager) {
    audioStreamManager = manager;
  }

  Future<Map<String, dynamic>> sendInteraction(Map<String, dynamic> requestPayload) async {
    return circuitBreaker.execute(() async {
      if (audioStreamManager == null) {
        throw Exception('AudioStreamManager is not initialized for InteractionClient.');
      }
      
      // Fire and forget via WebSocket
      audioStreamManager!.sendTelemetry(requestPayload);
      
      // Return a pending or mock status since actual response comes asynchronously via WebSocket
      return <String, dynamic>{
        'dialogue_mode': 'query',
        'llm_gate_status': 'pass',
        'last_utterance': '',
        'bcp': <String, dynamic>{},
        '_info': 'Async via WebSocket'
      };
    });
  }
}

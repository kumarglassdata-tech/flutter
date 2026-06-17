import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

import 'package:smartglass_flutter/core/services/audio_stream_manager.dart';

class InteractionClient {
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final bool fallbackToMock;
  final void Function(String source, String message, {String? jsonPayload, String? stackTrace, bool isError})? onDiagnosticLog;
  AudioStreamManager? audioStreamManager;

  InteractionClient({
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.onDiagnosticLog,
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
      onDiagnosticLog?.call(
        'InteractionEngine',
        'WebSocket Send',
        jsonPayload: jsonEncode(requestPayload),
      );
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

  Future<void> setLocation(double lat, double lon, String city, String country) async {
    final url = Uri.parse('${EngineRegistry.interactionUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://')}/set_location');
    try {
      final payload = jsonEncode({
          'latitude': lat,
          'longitude': lon,
          'city': city,
          'country': country,
        });
      
      onDiagnosticLog?.call(
        'InteractionEngine',
        'POST /set_location Request',
        jsonPayload: payload,
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      if (response.statusCode != 200) {
        final errorMsg = 'Failed to set location: ${response.statusCode} - ${response.body}';
        onDiagnosticLog?.call('InteractionEngine', 'Error POST /set_location', isError: true, stackTrace: errorMsg);
        debugPrint(errorMsg);
      } else {
        onDiagnosticLog?.call('InteractionEngine', 'POST /set_location Success');
      }
    } catch (e, st) {
      onDiagnosticLog?.call('InteractionEngine', 'Exception in setLocation', isError: true, stackTrace: '$e\n$st');
      debugPrint('Error setting location: $e');
    }
  }
}

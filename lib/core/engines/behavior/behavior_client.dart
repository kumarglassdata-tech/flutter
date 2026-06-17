import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

class BehaviorClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final String? baseUrl;

  final bool fallbackToMock;
  final void Function(String source, String message, {String? jsonPayload, String? stackTrace, bool isError})? onDiagnosticLog;

  BehaviorClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.onDiagnosticLog,
    this.baseUrl,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'BehaviorEngine');

  Future<Map<String, dynamic>> sendBehavior(Map<String, dynamic> requestPayload) async {
    return circuitBreaker.execute(() async {
      final resolvedUrl = baseUrl ?? EngineRegistry.getEngineUrl('behavior');
      final url = Uri.parse(resolvedUrl);
      final body = jsonEncode(requestPayload);

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          onDiagnosticLog?.call(
            'BehaviorEngine',
            'POST /api/v1/process Request',
            jsonPayload: body,
          );

          final response = await _client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            final errorMsg = 'Behavior Engine HTTP ${response.statusCode} - ${response.body}';
            onDiagnosticLog?.call('BehaviorEngine', 'Error POST /api/v1/process', isError: true, stackTrace: errorMsg);
            if (fallbackToMock) {
              onDiagnosticLog?.call('BehaviorEngine', 'Falling back to mock due to HTTP error');
              return _behaviorMock();
            }
            throw Exception(errorMsg);
          }

          final parsed = jsonDecode(response.body) as Map<String, dynamic>;
          onDiagnosticLog?.call(
            'BehaviorEngine',
            'POST /api/v1/process Response',
            jsonPayload: response.body,
          );
          return parsed;
        } catch (e, st) {
          if (attempt > _retryPolicy.attempts) {
            onDiagnosticLog?.call('BehaviorEngine', 'Max retries reached', isError: true, stackTrace: '$e\n$st');
            if (fallbackToMock) {
              onDiagnosticLog?.call('BehaviorEngine', 'Falling back to mock due to exceptions');
              return _behaviorMock();
            }
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }

  Map<String, dynamic> _behaviorMock() => {
    'behavioral_state': 'product_interest',
    'state_confidence': 0.88,
    'gaze_grounding': {'grounded_target': 'organic_milk_1l'},
    'relevance_score': 0.85,
    'top_salient_objects': [
      {'object_id': 102, 'class_name': 'organic_milk_1l', 'salience_score': 0.88}
    ],
  };
}

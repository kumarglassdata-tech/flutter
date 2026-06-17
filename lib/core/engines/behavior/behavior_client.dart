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

  BehaviorClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
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
          final response = await _client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (fallbackToMock) return _behaviorMock();
            throw Exception('Behavior Engine HTTP ${response.statusCode}');
          }

          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) return _behaviorMock();
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

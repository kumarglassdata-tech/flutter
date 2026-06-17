import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

class EcomClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;

  final bool fallbackToMock;

  EcomClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'EcomAddHandler');

  Future<Map<String, dynamic>> queryEcom(Map<String, dynamic> requestPayload) async {
    return circuitBreaker.execute(() async {
      // action_type drives which endpoint: buy | recommend | lifebalance | analyze
      final actionType = requestPayload['action_type'] as String? ?? 'buy';
      final resolvedUrl = EngineRegistry.getEngineUrl(actionType);
      final url = Uri.parse(resolvedUrl);
      final body = jsonEncode(requestPayload..remove('action_type'));

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
            if (fallbackToMock) {
              return {
                "suggestions": [
                  {"item_id": 1, "name": "Organic Milk", "price": 4.99}
                ]
              };
            }
            throw Exception('Ecom Engine server error: HTTP ${response.statusCode}');
          }

          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) {
              return {
                "suggestions": [
                  {"item_id": 1, "name": "Organic Milk", "price": 4.99}
                ]
              };
            }
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }
}

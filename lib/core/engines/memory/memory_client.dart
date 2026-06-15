import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class MemoryClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final String? baseUrl;

  final bool fallbackToMock;

  MemoryClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.baseUrl,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'SafetyMemory');

  Future<Map<String, dynamic>> storeMemory(Map<String, dynamic> payload) async {
    return circuitBreaker.execute(() async {
      final url = Uri.parse(baseUrl ?? EngineRegistry.getEngineUrl('memory'));
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Memory store failed: HTTP ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> recallMemory(Map<String, dynamic> payload) async {
    return circuitBreaker.execute(() async {
      final baseUri = Uri.parse(baseUrl ?? EngineRegistry.getEngineUrl('memory'));
      final queryText = payload['query']?.toString() ?? '';
      
      // Safety Memory engine expects GET /api/release?text=...
      final url = baseUri.replace(queryParameters: {'text': queryText});

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          final response = await _client.get(
            url,
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (fallbackToMock) return MemoryResponse.mock().raw;
            throw Exception('Memory recall failed: HTTP ${response.statusCode}');
          }

          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) return MemoryResponse.mock().raw;
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }
}

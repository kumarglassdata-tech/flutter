import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

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
    return {'status': 'success'};
  }

  Future<Map<String, dynamic>> recallMemory(Map<String, dynamic> payload) async {
    return circuitBreaker.execute(() async {
      final resolvedUrl = baseUrl ?? EngineRegistry.getEngineUrl('memory');
      final Uri url;
      final bool isReleaseGateway = resolvedUrl.contains('glassdata.ai');
      if (isReleaseGateway) {
        final baseUrlStr = resolvedUrl.split('?').first;
        url = Uri.parse('$baseUrlStr?text=${Uri.encodeComponent(payload['query'] ?? '')}');
      } else {
        if (resolvedUrl.endsWith('/') && !resolvedUrl.contains('/api/')) {
          url = Uri.parse('${resolvedUrl}api/v1/memory/all');
        } else if (!resolvedUrl.contains('/api/') && resolvedUrl.contains('glassdata.ai')) {
          url = Uri.parse('$resolvedUrl/api/v1/memory/all');
        } else {
          url = Uri.parse(resolvedUrl);
        }
      }

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          final response = await _client.get(
            url,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (fallbackToMock) {
              return {
                "past_interactions": []
              };
            }
            throw Exception('Safety Memory recall error: HTTP ${response.statusCode}');
          }

          final responseMap = jsonDecode(response.body) as Map<String, dynamic>;
          if (responseMap.containsKey('memory_response')) {
            return responseMap['memory_response'] as Map<String, dynamic>;
          }
          return responseMap;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) {
              return {
                "past_interactions": []
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

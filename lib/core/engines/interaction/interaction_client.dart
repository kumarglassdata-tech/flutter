import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

class InteractionClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;

  final bool fallbackToMock;

  InteractionClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'InteractionSubsystem');

  Future<Map<String, dynamic>> sendInteraction(Map<String, dynamic> requestPayload) async {
    return circuitBreaker.execute(() async {
      final body = jsonEncode(requestPayload);
      final baseUrl = EngineRegistry.interactionSubUrl;
      final Uri url;
      final bool isReleaseGateway = baseUrl.contains('release');
      if (isReleaseGateway) {
        url = Uri.parse('$baseUrl?text=${Uri.encodeComponent(requestPayload['utterance'] ?? '')}');
      } else {
        if (baseUrl.endsWith('/') && !baseUrl.contains('/process')) {
          url = Uri.parse('${baseUrl}process');
        } else if (!baseUrl.contains('/process') && baseUrl.contains('glassdata.ai')) {
          url = Uri.parse('$baseUrl/process');
        } else {
          url = Uri.parse(baseUrl);
        }
      }

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          final http.Response response;
          if (isReleaseGateway) {
            response = await _client.get(
              url,
            ).timeout(const Duration(seconds: 8));
          } else {
            response = await _client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            ).timeout(const Duration(seconds: 8));
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('Interaction Subsystem server error: HTTP ${response.statusCode}');
          }

          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }
}

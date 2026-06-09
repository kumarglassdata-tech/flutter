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
      final body = jsonEncode(requestPayload);
      final resolvedUrl = EngineRegistry.ecomHandlerUrl;
      final Uri url;
      if (resolvedUrl.endsWith('/buy')) {
        url = Uri.parse(resolvedUrl);
      } else {
        final base = resolvedUrl.endsWith('/') ? resolvedUrl.substring(0, resolvedUrl.length - 1) : resolvedUrl;
        url = Uri.parse('$base/buy');
      }

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
            throw Exception('Ecom Engine server error: HTTP ${response.statusCode}');
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

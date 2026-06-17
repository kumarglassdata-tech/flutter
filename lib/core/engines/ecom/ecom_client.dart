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
  final void Function(String source, String message, {String? jsonPayload, String? stackTrace, bool isError})? onDiagnosticLog;

  EcomClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.onDiagnosticLog,
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
          onDiagnosticLog?.call(
            'EcomClient',
            'POST /${url.pathSegments.last} Request',
            jsonPayload: body,
          );

          final response = await _client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            final errorMsg = 'Ecom Engine HTTP ${response.statusCode} - ${response.body}';
            onDiagnosticLog?.call('EcomClient', 'Error POST /${url.pathSegments.last}', isError: true, stackTrace: errorMsg);
            if (fallbackToMock) {
              onDiagnosticLog?.call('EcomClient', 'Falling back to mock due to HTTP error');
              return { "suggestions": [] };
            }
            throw Exception(errorMsg);
          }

          final parsed = jsonDecode(response.body) as Map<String, dynamic>;
          onDiagnosticLog?.call(
            'EcomClient',
            'POST /${url.pathSegments.last} Response',
            jsonPayload: response.body,
          );
          return parsed;
        } catch (e, st) {
          if (attempt > _retryPolicy.attempts) {
            onDiagnosticLog?.call('EcomClient', 'Max retries reached', isError: true, stackTrace: '$e\n$st');
            if (fallbackToMock) {
              onDiagnosticLog?.call('EcomClient', 'Falling back to mock due to exceptions');
              return { "suggestions": [] };
            }
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }
}

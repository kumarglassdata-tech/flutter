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
  final void Function(String source, String message, {String? jsonPayload, String? stackTrace, bool isError})? onDiagnosticLog;

  MemoryClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.onDiagnosticLog,
    this.baseUrl,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'SafetyMemory');

  Future<Map<String, dynamic>> storeMemory(Map<String, dynamic> payload) async {
    return circuitBreaker.execute(() async {
      final url = Uri.parse(baseUrl ?? EngineRegistry.getEngineUrl('memory'));
      
      var request = http.MultipartRequest('POST', url);
      
      // Add standard fields
      payload.forEach((key, value) {
        if (key != 'content') {
           request.fields[key] = value.toString();
        }
      });
      
      // Add the content as the 'file' field the backend requires
      final contentStr = payload['content']?.toString() ?? '';
      request.files.add(http.MultipartFile.fromString(
        'file',
        contentStr,
        filename: 'memory.txt'
      ));
      
      onDiagnosticLog?.call(
        'SafetyMemory',
        'POST /memory Request',
        jsonPayload: jsonEncode(payload),
      );
      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMsg = 'Memory store failed: HTTP ${response.statusCode} - ${response.body}';
        onDiagnosticLog?.call('SafetyMemory', 'Error POST /memory', isError: true, stackTrace: errorMsg);
        throw Exception(errorMsg);
      }
      onDiagnosticLog?.call(
        'SafetyMemory',
        'POST /memory Response',
        jsonPayload: response.body,
      );
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
          onDiagnosticLog?.call(
            'SafetyMemory',
            'GET /api/release Request',
            jsonPayload: jsonEncode({'text': queryText}),
          );

          final response = await _client.get(
            url,
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            final errorMsg = 'Memory recall failed: HTTP ${response.statusCode} - ${response.body}';
            onDiagnosticLog?.call('SafetyMemory', 'Error GET /api/release', isError: true, stackTrace: errorMsg);
            if (fallbackToMock) {
              onDiagnosticLog?.call('SafetyMemory', 'Falling back to mock due to HTTP error');
              return MemoryResponse.mock().raw;
            }
            throw Exception(errorMsg);
          }

          final parsed = jsonDecode(response.body) as Map<String, dynamic>;
          onDiagnosticLog?.call(
            'SafetyMemory',
            'GET /api/release Response',
            jsonPayload: response.body,
          );
          return parsed;
        } catch (e, st) {
          if (attempt > _retryPolicy.attempts) {
            onDiagnosticLog?.call('SafetyMemory', 'Max retries reached', isError: true, stackTrace: '$e\n$st');
            if (fallbackToMock) {
              onDiagnosticLog?.call('SafetyMemory', 'Falling back to mock due to exceptions');
              return MemoryResponse.mock().raw;
            }
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }
}

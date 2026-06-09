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

  Future<Map<String, dynamic>> sendBehavior(Map<String, dynamic> contextData) async {
    return circuitBreaker.execute(() async {
      String text = 'Voice intent processing';
      final ctxData = contextData['context_data'];
      if (ctxData is Map) {
        final results = ctxData['results'];
        if (results is Map && results['vision'] is Map && results['vision']['objects'] is List) {
          final list = results['vision']['objects'] as List;
          if (list.isNotEmpty) {
            final firstObj = list.first;
            if (firstObj is Map && firstObj['class'] != null) {
              text = "User looking at ${firstObj['class']}";
            }
          }
        } else {
          final rawObjects = ctxData['detected_objects'] ?? ctxData['tracked_objects'];
          if (rawObjects is List && rawObjects.isNotEmpty) {
            final first = rawObjects.first;
            if (first is Map) {
              text = "User looking at ${first['label'] ?? first['name'] ?? 'object'}";
            } else {
              text = "User looking at $first";
            }
          }
        }
      }

      final resolvedUrl = baseUrl ?? EngineRegistry.getEngineUrl('behavior');
      final Uri url;
      final bool isReleaseGateway = resolvedUrl.contains('/release');
      if (isReleaseGateway) {
        url = Uri.parse('https://myna-sme-dev.glassdata.ai/api/release?text=${Uri.encodeComponent(text)}');
      } else {
        if (resolvedUrl.endsWith('/') && !resolvedUrl.contains('/api/')) {
          url = Uri.parse('${resolvedUrl}api/v1/voice/command');
        } else {
          url = Uri.parse(resolvedUrl);
        }
      }

      final Map<String, dynamic> bodyMap = {
        ...contextData,
      };
      final body = jsonEncode(bodyMap);

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
            throw Exception('Behavior Engine server error: HTTP ${response.statusCode}');
          }

          final responseMap = jsonDecode(response.body) as Map<String, dynamic>;
          if (responseMap.containsKey('voice_assistant_response')) {
            final Map<String, dynamic> mapped = Map<String, dynamic>.from(responseMap);
            mapped['intent'] = responseMap['voice_assistant_response']?['intent'];
            return mapped;
          }
          return responseMap;
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

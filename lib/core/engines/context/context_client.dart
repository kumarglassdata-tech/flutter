import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

class ContextClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final String? baseUrl;

  final bool fallbackToMock;

  ContextClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.baseUrl,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'ContextEngine');

  Future<Map<String, dynamic>> sendContext({
    required Uint8List imageBytes,
    required List<double> audioFeatures,
    required double latitude,
    required double longitude,
  }) async {
    return circuitBreaker.execute(() async {
      final resolvedUrl = baseUrl ?? EngineRegistry.contextUrl;
      final Uri url;
      final bool hasFrame = imageBytes.isNotEmpty;

      if (!hasFrame) {
        final separator = resolvedUrl.contains('?') ? '&' : '?';
        final audioVal = audioFeatures.isNotEmpty ? audioFeatures.first : 0.0;
        url = Uri.parse('$resolvedUrl${separator}latitude=$latitude&longitude=$longitude&audio_level=$audioVal');
      } else {
        if (resolvedUrl.endsWith('/inp')) {
           url = Uri.parse(resolvedUrl);
        } else {
           final base = resolvedUrl.endsWith('/') ? resolvedUrl.substring(0, resolvedUrl.length - 1) : resolvedUrl;
           url = Uri.parse('$base/inp');
        }
      }

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          final http.Response response;
          if (!hasFrame) {
            response = await _client.get(
              url,
            ).timeout(const Duration(seconds: 8));
          } else {
            // Send JSON POST to /inp
            final base64Image = await compute(base64Encode, imageBytes);
            final postResponse = await _client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'camera': {
                  'image_base64': base64Image
                },
                'audio': {
                  'samples': audioFeatures
                },
                'location': {'latitude': latitude, 'longitude': longitude},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })
            ).timeout(const Duration(seconds: 8));

            if (postResponse.statusCode < 200 || postResponse.statusCode >= 300) {
              throw Exception('Context HTTP POST ${postResponse.statusCode} - URL: $url - BODY: ${postResponse.body}');
            }

            // Immediately GET /predict to fetch the processed context
            final predictUrl = url.toString().replaceAll('/inp', '/predict');
            response = await _client.get(
              Uri.parse(predictUrl)
            ).timeout(const Duration(seconds: 8));
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            print('CONTEXT ENGINE ERROR: URL: $url | METHOD: ${response.request?.method} | STATUS: ${response.statusCode} | BODY: ${response.body}');
            if (fallbackToMock) {
              return {
                "scene_context": {"scene_label": "User walking in retail store", "scene_confidence": 0.92},
                "tracked_objects": [{"object_id": 102, "label": "organic_milk_1l", "confidence": 0.94, "bbox_xyxy": [200.0, 150.0, 400.0, 350.0]}],
                "product_salience": {"102": 0.925},
                "attention_grounding": {"attention_target": "organic_milk_1l", "attention_confidence": 0.91}
              };
            }
            throw Exception('Context HTTP ${response.statusCode} - URL: $url - BODY: ${response.body}');
          }

          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) {
              return {
                "scene_context": {"scene_label": "User walking in retail store", "scene_confidence": 0.92},
                "tracked_objects": [{"object_id": 102, "label": "organic_milk_1l", "confidence": 0.94, "bbox_xyxy": [200.0, 150.0, 400.0, 350.0]}],
                "product_salience": {"102": 0.925},
                "attention_grounding": {"attention_target": "organic_milk_1l", "attention_confidence": 0.91}
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

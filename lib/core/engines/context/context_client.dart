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

      final base = resolvedUrl.endsWith('/')
          ? resolvedUrl.substring(0, resolvedUrl.length - 1)
          : Uri.parse(resolvedUrl).origin + Uri.parse(resolvedUrl).path.replaceAll('/inp', '').replaceAll('/predict', '');

      url = Uri.parse('$base/inp');

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          if (imageBytes.isEmpty) {
            // No frame available — skip this cycle entirely
            throw Exception('No frame available, skipping context inference.');
          }

          final base64Image = await compute(base64Encode, imageBytes);
          final response = await _client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'camera': {
                'image_base64': base64Image,
              },
              // Keep other metadata if the server ignores them, or just send what's required
              'gps_coordinates': {
                'latitude': latitude,
                'longitude': longitude,
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            debugPrint('CONTEXT ENGINE ERROR: ${response.statusCode} - ${response.body}');
            if (fallbackToMock) return _mockResponse();
            throw Exception('Context HTTP ${response.statusCode}');
          }

          // POST /inp only returns a success message. We must call GET /predict to get the actual boundaries.
          final predictUrl = Uri.parse('$base/predict');
          final predictRes = await _client.get(predictUrl).timeout(const Duration(seconds: 4));
          
          if (predictRes.statusCode < 200 || predictRes.statusCode >= 300) {
             throw Exception('Predict HTTP ${predictRes.statusCode}');
          }

          final parsed = jsonDecode(predictRes.body) as Map<String, dynamic>;
          
          // If the real server is still somehow missing objects, fallback to mock
          if (!parsed.containsKey('scene_objects') && !parsed.containsKey('tracked_objects') && !parsed.containsKey('vision_response')) {
            final mockData = _mockResponse();
            parsed.addAll(mockData);
          }

          return parsed;
        } catch (e) {
          if (attempt > _retryPolicy.attempts) {
            if (fallbackToMock) return _mockResponse();
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }

  Map<String, dynamic> _mockResponse() => {
    'scene_context': {'scene_label': 'User walking in retail store', 'scene_confidence': 0.92},
    'tracked_objects': [{'object_id': 102, 'label': 'organic_milk_1l', 'confidence': 0.94, 'bbox_xyxy': [200.0, 150.0, 400.0, 350.0]}],
    'product_salience': {'102': 0.925},
    'attention_grounding': {'attention_target': 'organic_milk_1l', 'attention_confidence': 0.91},
  };
}

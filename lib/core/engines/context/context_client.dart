import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
        // If not explicitly pointing to an endpoint, append /process_frame
        if (resolvedUrl.endsWith('.ai') || resolvedUrl.endsWith('/')) {
           final base = resolvedUrl.endsWith('/') ? resolvedUrl.substring(0, resolvedUrl.length - 1) : resolvedUrl;
           url = Uri.parse('$base/process_frame');
        } else {
           url = Uri.parse(resolvedUrl);
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
            // Check if we should also notify the Streamlit dashboard via /inp
            if (url.host.contains('sme-dev') || url.host.contains('ce-dev')) {
              try {
                final base64Image = base64Encode(imageBytes);
                _client.post(
                  Uri.parse('https://myna-ce-dev.glassdata.ai/inp'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'camera': {
                      'image_base64': base64Image
                    }
                  })
                ).catchError((_) => http.Response('error', 500)); // Fire and forget
              } catch (_) {}
            }

            final request = http.MultipartRequest('POST', url);
            request.files.add(
              http.MultipartFile.fromBytes(
                'file',
                imageBytes,
                filename: 'frame.jpg',
              ),
            );
            request.fields['gps_hazard'] = 'false';

            final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 8));
            response = await http.Response.fromStream(streamedResponse);
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            print('CONTEXT ENGINE ERROR: URL: $url | METHOD: ${response.request?.method} | STATUS: ${response.statusCode} | BODY: ${response.body}');
            throw Exception('Context HTTP ${response.statusCode} - URL: $url - BODY: ${response.body}');
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

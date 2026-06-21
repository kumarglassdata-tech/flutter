import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/retry_policy.dart';

class EcomClient {
  final http.Client _client;
  final CircuitBreaker circuitBreaker;
  final RetryPolicy _retryPolicy;
  final String? baseUrl;

  final bool fallbackToMock;
  final void Function(String source, String message,
      {String? jsonPayload, String? stackTrace, bool isError})? onDiagnosticLog;

  EcomClient({
    http.Client? client,
    RetryPolicy? retryPolicy,
    this.fallbackToMock = false,
    this.onDiagnosticLog,
    this.baseUrl,
  })  : _client = client ?? http.Client(),
        _retryPolicy = retryPolicy ?? RetryPolicy(attempts: 2),
        circuitBreaker = CircuitBreaker(name: 'EcomAddHandler');

  Future<Map<String, dynamic>> queryEcom(
      Map<String, dynamic> requestPayload) async {
    return circuitBreaker.execute(() async {
      final base = _resolveActionHubBaseUrl();
      final inputUrl = Uri.parse('$base/inp/');
      final recommendUrl = Uri.parse('$base/recommend');
      final buyUrl = Uri.parse('$base/buy');
      final analyzeUrl = Uri.parse('$base/analyze');
      final lifeBalanceUrl = Uri.parse('$base/lifebalance');
      final body = jsonEncode(requestPayload);

      var attempt = 0;
      while (true) {
        attempt++;
        try {
          onDiagnosticLog?.call(
            'EcomClient',
            'POST /inp Request',
            jsonPayload: body,
          );

          final inputResponse = await _client
              .post(
                inputUrl,
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(const Duration(seconds: 8));

          if (inputResponse.statusCode < 200 ||
              inputResponse.statusCode >= 300) {
            final errorMsg =
                'Ecom input failed: HTTP ${inputResponse.statusCode} - ${inputResponse.body}';
            onDiagnosticLog?.call('EcomClient', 'Error POST /inp',
                isError: true, stackTrace: errorMsg);
            if (fallbackToMock) {
              onDiagnosticLog?.call(
                  'EcomClient', 'Falling back to mock due to HTTP error');
              return {"suggestions": []};
            }
            throw Exception(errorMsg);
          }

          onDiagnosticLog?.call(
            'EcomClient',
            'POST /inp Response',
            jsonPayload: inputResponse.body,
          );

          onDiagnosticLog?.call('EcomClient', 'GET parallel requests starting');
          
          final responses = await Future.wait([
            _client.get(recommendUrl, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8)),
            _client.get(buyUrl, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8)),
            _client.get(analyzeUrl, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8)),
            _client.get(lifeBalanceUrl, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8)),
          ]);

          for (final res in responses) {
            if (res.statusCode < 200 || res.statusCode >= 300) {
              final errorMsg = 'Ecom GET failed: HTTP ${res.statusCode} - ${res.request?.url}';
              onDiagnosticLog?.call('EcomClient', 'Error GET', isError: true, stackTrace: errorMsg);
              // We could throw here or just gracefully handle missing endpoints. For now, we continue if possible, or throw if required.
              // Let's log it but try to parse whatever succeeded.
            }
          }

          Map<String, dynamic> combinedResponse = {};
          
          try {
            if (responses[0].statusCode == 200) {
              combinedResponse.addAll(jsonDecode(responses[0].body) as Map<String, dynamic>);
            }
          } catch (_) {}

          try {
            if (responses[1].statusCode == 200) {
              final parsedBuy = _decodeBuyResponse(responses[1].body);
              // merge suggestions
              if (combinedResponse['suggestions'] == null) {
                combinedResponse['suggestions'] = parsedBuy['suggestions'];
              } else {
                (combinedResponse['suggestions'] as List).addAll(parsedBuy['suggestions'] as List);
              }
            }
          } catch (_) {}

          try {
            if (responses[2].statusCode == 200) {
              combinedResponse['analyze_response'] = jsonDecode(responses[2].body);
            }
          } catch (_) {}

          try {
            if (responses[3].statusCode == 200) {
              combinedResponse['lifebalance_response'] = jsonDecode(responses[3].body);
            }
          } catch (_) {}

          onDiagnosticLog?.call(
            'EcomClient',
            'GET Parallel Responses Complete',
            jsonPayload: jsonEncode(combinedResponse),
          );
          
          return combinedResponse;
        } catch (e, st) {
          if (attempt > _retryPolicy.attempts) {
            onDiagnosticLog?.call('EcomClient', 'Max retries reached',
                isError: true, stackTrace: '$e\n$st');
            if (fallbackToMock) {
              onDiagnosticLog?.call(
                  'EcomClient', 'Falling back to mock due to exceptions');
              return {"suggestions": []};
            }
            rethrow;
          }
          await Future.delayed(_retryPolicy.backoffDelay(attempt));
        }
      }
    });
  }

  String _resolveActionHubBaseUrl() {
    final explicitBase = baseUrl ?? EngineRegistry.ecomUrl;
    if (explicitBase.isNotEmpty) {
      return _stripKnownEndpoint(explicitBase);
    }
    return _stripKnownEndpoint(EngineRegistry.actionHubBuyUrl);
  }

  String _stripKnownEndpoint(String url) {
    final normalized =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (normalized.endsWith('/inp')) {
      return normalized.substring(0, normalized.length - '/inp'.length);
    }
    if (normalized.endsWith('/input')) {
      return normalized.substring(0, normalized.length - '/input'.length);
    }
    if (normalized.endsWith('/buy')) {
      return normalized.substring(0, normalized.length - '/buy'.length);
    }
    return normalized;
  }

  Map<String, dynamic> _decodeBuyResponse(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return {
        'status': 'success',
        'suggestions': decoded,
      };
    }
    if (decoded is String) {
      return {
        'status': 'success',
        'suggestions': [
          {'link': decoded}
        ],
      };
    }
    return {
      'status': 'success',
      'data': decoded,
    };
  }
}

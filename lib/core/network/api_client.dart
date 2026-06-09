import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_routes.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(ApiRoute route) async {
    final response = await _httpClient.get(Uri.parse(route.url));
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    ApiRoute route, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(route.url),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeJsonResponse(response);
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        'Request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }
}

class ApiClientException implements Exception {
  ApiClientException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() {
    return 'ApiClientException(message: $message, statusCode: $statusCode, body: $body)';
  }
}
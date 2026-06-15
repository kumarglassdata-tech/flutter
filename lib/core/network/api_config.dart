import 'package:smartglass_flutter/core/config/env_config.dart';

class ApiConfig {
  const ApiConfig._();

  static String get baseUrl => EnvConfig.apiBaseUrl;
  static String get apiPrefix => EnvConfig.apiPrefix;

  static String buildUrl(String route) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedRoute = route.startsWith('/') ? route : '/$route';
    return '$normalizedBase$apiPrefix$normalizedRoute';
  }
}
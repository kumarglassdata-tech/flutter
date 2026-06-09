import 'api_config.dart';

enum ApiRoute {
  health('/health'),
  capture('/capture'),
  vision('/vision'),
  speech('/speech'),
  reasoning('/reasoning'),
  recommendations('/recommendations'),
  session('/session'),
  diagnostics('/diagnostics');

  const ApiRoute(this.path);

  final String path;
}

extension ApiRouteX on ApiRoute {
  String get url => ApiConfig.buildUrl(path);
}
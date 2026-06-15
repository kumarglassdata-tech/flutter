import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? const String.fromEnvironment('API_BASE_URL');
  static String get apiPrefix => dotenv.env['API_PREFIX'] ?? const String.fromEnvironment('API_PREFIX');

  // Context Engine — POST /inp  |  GET /predict
  static String get contextEngineUrl => dotenv.env['CONTEXT_ENGINE_URL'] ?? const String.fromEnvironment('CONTEXT_ENGINE_URL');

  // Interaction Engine — WebSocket
  static String get interactionWsUrl => dotenv.env['INTERACTION_WS_URL'] ?? const String.fromEnvironment('INTERACTION_WS_URL');

  // Behaviour Engine — POST /api/v1/process
  static String get behaviourIntentUrl => dotenv.env['BEHAVIOR_ENGINE_URL'] ?? const String.fromEnvironment('BEHAVIOR_ENGINE_URL');

  // Ecom Ad Handler
  static String get actionHubBaseUrl => dotenv.env['ACTION_HUB_BASE_URL'] ?? const String.fromEnvironment('ACTION_HUB_BASE_URL');
  static String get actionHubBuyUrl => dotenv.env['ACTION_HUB_BUY_URL'] ?? const String.fromEnvironment('ACTION_HUB_BUY_URL');
  static String get actionHubRecommendUrl => dotenv.env['ACTION_HUB_RECOMMEND_URL'] ?? const String.fromEnvironment('ACTION_HUB_RECOMMEND_URL');
  static String get actionHubLifebalanceUrl => dotenv.env['ACTION_HUB_LIFEBALANCE_URL'] ?? const String.fromEnvironment('ACTION_HUB_LIFEBALANCE_URL');
  static String get actionHubAnalyzeUrl => dotenv.env['ACTION_HUB_ANALYZE_URL'] ?? const String.fromEnvironment('ACTION_HUB_ANALYZE_URL');

  // Safety Memory Engine — POST /api/release
  static String get safetyMemoryUrl => dotenv.env['SAFETY_MEMORY_URL'] ?? const String.fromEnvironment('SAFETY_MEMORY_URL');
}

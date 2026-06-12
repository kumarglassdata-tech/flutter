class EnvConfig {
  EnvConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://myna-prototype-api.glassdata.ai',
  );

  static const String apiPrefix = String.fromEnvironment(
    'API_PREFIX',
    defaultValue: '/api',
  );

  static const String contextEngineUrl = String.fromEnvironment(
    'CONTEXT_ENGINE_URL',
    defaultValue: 'https://myna-ce-dev.glassdata.ai/inp',
  );

  static const String interactionSubUrl = String.fromEnvironment(
    'INTERACTION_SUB_URL',
    defaultValue: 'https://myna-ie-dev.glassdata.ai/process',
  );

  static const String interactionWsUrl = String.fromEnvironment(
    'INTERACTION_WS_URL',
    defaultValue: 'wss://myna-ie-dev.glassdata.ai/ws',
  );

  static const String actionHubBaseUrl = String.fromEnvironment(
    'ACTION_HUB_BASE_URL',
    defaultValue: 'https://myna-ah-dev.glassdata.ai',
  );

  static const String actionHubBuyUrl = '\$actionHubBaseUrl/buy';
  static const String actionHubRecommendUrl = '\$actionHubBaseUrl/recommend';
  static const String actionHubLifebalanceUrl = '\$actionHubBaseUrl/lifebalance';
  static const String actionHubAnalyzeUrl = '\$actionHubBaseUrl/analyze';

  static const String behaviourIntentUrl = String.fromEnvironment(
    'BEHAVIOR_ENGINE_URL',
    defaultValue: String.fromEnvironment(
      'BEHAVIOR_INTENT_URL',
      defaultValue: 'https://myna-be-dev.glassdata.ai/api/v1/process',
    ),
  );

  static const String safetyMemoryUrl = String.fromEnvironment(
    'SAFETY_MEMORY_URL',
    defaultValue: 'https://myna-sme-dev.glassdata.ai/api/release',
  );
}

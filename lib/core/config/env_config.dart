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
    defaultValue: 'https://myna-sme-dev.glassdata.ai/api/release',
  );

  static const String interactionSubUrl = String.fromEnvironment(
    'INTERACTION_SUB_URL',
    defaultValue: 'https://myna-ie-dev.glassdata.ai/process',
  );

  static const String ecomHandlerUrl = String.fromEnvironment(
    'ECOM_HANDLER_URL',
    defaultValue: 'https://myna-ah-dev.glassdata.ai/buy',
  );

  static const String behaviourIntentUrl = String.fromEnvironment(
    'BEHAVIOR_ENGINE_URL',
    defaultValue: String.fromEnvironment(
      'BEHAVIOR_INTENT_URL',
      defaultValue: 'https://myna-ie-dev.glassdata.ai/process',
    ),
  );

  static const String safetyMemoryUrl = String.fromEnvironment(
    'SAFETY_MEMORY_URL',
    defaultValue: 'https://myna-sme-dev.glassdata.ai/api/release',
  );
}

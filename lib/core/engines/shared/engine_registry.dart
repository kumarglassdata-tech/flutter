import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/network/api_config.dart';

class EngineRegistry {
  EngineRegistry._();

  static String get contextUrl => EnvConfig.contextEngineUrl;
  static String get actionHubBuyUrl => EnvConfig.actionHubBuyUrl;
  static String get actionHubRecommendUrl => EnvConfig.actionHubRecommendUrl;
  static String get actionHubLifebalanceUrl => EnvConfig.actionHubLifebalanceUrl;
  static String get actionHubAnalyzeUrl => EnvConfig.actionHubAnalyzeUrl;
  static String get behaviourIntentUrl => EnvConfig.behaviourIntentUrl;
  static String get safetyMemoryUrl => EnvConfig.safetyMemoryUrl;
  
  // Expose base URLs for health checks
  static String get interactionUrl => EnvConfig.interactionWsUrl.replaceFirst('wss://', 'https://').replaceFirst('/ws', '');
  static String get ecomUrl => EnvConfig.actionHubBaseUrl;

  /// Helper to build direct requests or default to ApiConfig if mono-endpoint.
  static String getEngineUrl(String key) {
    switch (key) {
      case 'context':
        return contextUrl;
      case 'buy':
        return actionHubBuyUrl;
      case 'recommend':
        return actionHubRecommendUrl;
      case 'lifebalance':
        return actionHubLifebalanceUrl;
      case 'analyze':
        return actionHubAnalyzeUrl;
      case 'behavior':
        return behaviourIntentUrl;
      case 'interaction':
        return interactionUrl;
      case 'ecom':
        return ecomUrl;
      case 'memory':
        return safetyMemoryUrl;
      default:
        return ApiConfig.baseUrl;
    }
  }
}

import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/network/api_config.dart';

class EngineRegistry {
  EngineRegistry._();

  static const String contextUrl = EnvConfig.contextEngineUrl;
  static const String interactionSubUrl = EnvConfig.interactionSubUrl;
  static const String actionHubBuyUrl = EnvConfig.actionHubBuyUrl;
  static const String actionHubRecommendUrl = EnvConfig.actionHubRecommendUrl;
  static const String actionHubLifebalanceUrl = EnvConfig.actionHubLifebalanceUrl;
  static const String actionHubAnalyzeUrl = EnvConfig.actionHubAnalyzeUrl;
  static const String behaviourIntentUrl = EnvConfig.behaviourIntentUrl;
  static const String safetyMemoryUrl = EnvConfig.safetyMemoryUrl;

  /// Helper to build direct requests or default to ApiConfig if mono-endpoint.
  static String getEngineUrl(String key) {
    switch (key) {
      case 'context':
        return contextUrl;
      case 'interaction':
        return interactionSubUrl;
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
      case 'memory':
        return safetyMemoryUrl;
      default:
        return ApiConfig.baseUrl;
    }
  }
}

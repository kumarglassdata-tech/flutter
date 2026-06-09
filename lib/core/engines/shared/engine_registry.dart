import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/network/api_config.dart';

class EngineRegistry {
  EngineRegistry._();

  static const String contextUrl = EnvConfig.contextEngineUrl;
  static const String interactionSubUrl = EnvConfig.interactionSubUrl;
  static const String ecomHandlerUrl = EnvConfig.ecomHandlerUrl;
  static const String behaviourIntentUrl = EnvConfig.behaviourIntentUrl;
  static const String safetyMemoryUrl = EnvConfig.safetyMemoryUrl;

  /// Helper to build direct requests or default to ApiConfig if mono-endpoint.
  static String getEngineUrl(String key) {
    switch (key) {
      case 'context':
        return contextUrl;
      case 'interaction':
        return interactionSubUrl;
      case 'ecom':
        return ecomHandlerUrl;
      case 'behavior':
        return behaviourIntentUrl.isNotEmpty ? behaviourIntentUrl : 'http://3.6.10.81:8502';
      case 'memory':
        return safetyMemoryUrl.isNotEmpty ? safetyMemoryUrl : 'http://3.6.10.81:8505';
      default:
        return ApiConfig.baseUrl;
    }
  }
}

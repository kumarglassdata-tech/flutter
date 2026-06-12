import 'unified_input.dart';

class EngineTelemetry {
  final String engine;
  final int latencyMs;
  final bool success;
  final String? error;
  final String pipelineId;

  const EngineTelemetry({
    required this.engine,
    required this.latencyMs,
    required this.success,
    required this.pipelineId,
    this.error,
  });
}

class EngineContext {
  final String pipelineId;
  final UnifiedInput input;
  final Map<String, dynamic> sharedState;
  final List<EngineTelemetry> telemetry;

  EngineContext({
    required this.pipelineId,
    required this.input,
    Map<String, dynamic>? sharedState,
    List<EngineTelemetry>? telemetry,
  })  : sharedState = sharedState ?? {},
        telemetry = telemetry ?? [];
}

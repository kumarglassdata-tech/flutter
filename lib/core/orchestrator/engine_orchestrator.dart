import '../models/engine_context.dart';

enum StepFailurePolicy {
  STOP_PIPELINE,
  CONTINUE,
}

class StepResult {
  final bool success;
  final String? error;

  const StepResult({required this.success, this.error});
}

abstract class EngineStep {
  final String name;

  EngineStep(this.name);

  StepFailurePolicy get failurePolicy;

  Future<StepResult> execute(EngineContext context);
}

class EngineOrchestrator {
  final List<EngineStep> _steps = [];

  void addStep(EngineStep step) {
    _steps.add(step);
  }

  Future<void> runPipeline(EngineContext context) async {
    for (final step in _steps) {
      final startTime = DateTime.now();
      try {
        final result = await step.execute(context);
        final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

        context.telemetry.add(EngineTelemetry(
          engine: step.name,
          latencyMs: latencyMs,
          success: result.success,
          error: result.error,
        ));

        if (!result.success && step.failurePolicy == StepFailurePolicy.STOP_PIPELINE) {
          print('[ORCHESTRATOR] Step ${step.name} failed and policy is STOP_PIPELINE. Halting.');
          break;
        }
      } catch (e) {
        final latencyMs = DateTime.now().difference(startTime).inMilliseconds;
        context.telemetry.add(EngineTelemetry(
          engine: step.name,
          latencyMs: latencyMs,
          success: false,
          error: e.toString(),
        ));

        if (step.failurePolicy == StepFailurePolicy.STOP_PIPELINE) {
          print('[ORCHESTRATOR] Step ${step.name} threw exception and policy is STOP_PIPELINE. Halting: $e');
          break;
        }
      }
    }
  }
}

import '../../models/domain/gate_decision.dart';
import '../../models/engine_models.dart';
import '../pipeline_step.dart';

class GateCheckStep extends PipelineStep<BIEFrame, bool> {
  GateCheckStep() : super('GateCheckStep');

  @override
  Future<PipelineResult<bool>> execute(
    BIEFrame input,
    Map<String, dynamic> sharedState,
  ) async {
    try {
      final score = input.salienceScore;

      // Respect the BE's own gate_open signal if present — it has more context
      final beGateOpen = input.raw['gate_open'] as bool?;
      final suppressReason = input.raw['suppress_reason']?.toString();

      GateDecision decision;

      if (beGateOpen == false) {
        // BE explicitly says do not interact
        decision = GateDecision(
          shouldInteract: false,
          shouldRunEcom: false,
          shouldPersistMemory: true,
          relevanceScore: score,
          reason: 'BE suppressed: ${suppressReason ?? "gate_open=false"}',
        );
      } else if (score < 0.5) {
        decision = GateDecision(
          shouldInteract: false,
          shouldRunEcom: false,
          shouldPersistMemory: false,
          relevanceScore: score,
          reason: 'Low relevance ($score). Halting pipeline interactions.',
        );
      } else if (score < 0.85) {
        decision = GateDecision(
          shouldInteract: true,
          shouldRunEcom: false,
          shouldPersistMemory: true,
          relevanceScore: score,
          reason: 'Moderate relevance ($score). Triggering interaction only.',
        );
      } else {
        decision = GateDecision(
          shouldInteract: true,
          shouldRunEcom: true,
          shouldPersistMemory: true,
          relevanceScore: score,
          reason: 'High relevance ($score). Triggering interaction and Action Hub lookup.',
        );
      }

      sharedState['gate_decision'] = decision;
      sharedState['gate_reason'] = decision.reason;
      sharedState['gate_open'] = decision.shouldInteract;

      if (!decision.shouldInteract) {
        return PipelineResult.success(false); // Valid completion, just returned false
      }

      return PipelineResult.success(true);
    } catch (e) {
      return PipelineResult.failure('Gate check exception: $e');
    }
  }
}

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

      // DEMO OVERRIDE: Force the gate to ALWAYS be open so the AI responds continuously.
      // Ignoring BE suppression and low salience scores to ensure constant interaction.
      decision = GateDecision(
        shouldInteract: true,
        shouldRunEcom: score >= 0.85,
        shouldPersistMemory: true,
        relevanceScore: score,
        reason: 'FORCED OPEN FOR DEMO (Original BE Gate: $beGateOpen, Score: $score)',
      );

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

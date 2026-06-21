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
      GateDecision decision = GateDecision(
        shouldInteract: true,
        shouldRunEcom: true,
        shouldPersistMemory: true, // Memory runs passively
        relevanceScore: input.salienceScore,
        reason: 'Gate bypassed - Backend now handles interaction logic.',
      );

      sharedState['gate_decision'] = decision;
      sharedState['gate_reason'] = decision.reason;
      sharedState['gate_open'] = decision.shouldInteract;

      return PipelineResult.success(true);
    } catch (e) {
      return PipelineResult.failure('Gate check exception: $e');
    }
  }
}


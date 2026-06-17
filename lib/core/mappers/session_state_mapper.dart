import '../models/domain/behavior_result.dart';
import '../models/domain/context_result.dart';
import '../models/domain/gate_decision.dart';
import '../models/engine_context.dart';

class SessionState {
  final bool isInteracting;
  final String uiOverlayText;
  final ActionHubResult? actionHubResult;
  final List<TrackedObjectDomain> activeBoundingBoxes;
  final String pipelineId;

  const SessionState({
    required this.isInteracting,
    required this.uiOverlayText,
    this.actionHubResult,
    required this.activeBoundingBoxes,
    required this.pipelineId,
  });
}

class SessionStateMapper {
  static SessionState mapFromEngine(EngineContext engineContext) {
    final contextResult = engineContext.sharedState['context_result'] as ContextResult?;
    final gateDecision = engineContext.sharedState['gate_decision'] as GateDecision?;
    final actionHubResult = engineContext.sharedState['action_hub_result'] as ActionHubResult?;

    return SessionState(
      pipelineId: engineContext.pipelineId,
      isInteracting: gateDecision?.shouldInteract ?? false,
      uiOverlayText: gateDecision?.reason ?? 'Processing...',
      actionHubResult: gateDecision?.shouldRunEcom == true ? actionHubResult : null,
      activeBoundingBoxes: contextResult?.trackedObjects ?? [],
    );
  }
}

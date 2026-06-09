import 'dart:async';
import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class GateCheckStep extends PipelineStep<BIEFrame, bool> {
  final double relevanceThreshold;
  final Map<String, int> _gazeFrequency = {};

  GateCheckStep({this.relevanceThreshold = 0.5}) : super('GateCheckStep');

  @override
  Future<PipelineResult<bool>> execute(
    BIEFrame input,
    Map<String, dynamic> sharedState,
  ) async {
    var salience = input.salienceScore;
    
    // Temporal salience boosting: If we see the same target multiple times, user is interested
    if (input.gazeTarget != 'unknown' && input.gazeTarget.isNotEmpty) {
      _gazeFrequency[input.gazeTarget] = (_gazeFrequency[input.gazeTarget] ?? 0) + 1;
      
      if ((_gazeFrequency[input.gazeTarget] ?? 0) >= 3 && salience < 0.86) {
        salience = 0.86;
        
        // Update shared state so downstream steps see the boosted salience
        sharedState['behavior_output'] = BIEFrame(
          intent: input.intent,
          confidence: input.confidence,
          gazeTarget: input.gazeTarget,
          salienceScore: salience,
          raw: input.raw,
        );
      }
    }

    final bool isRelevant = salience >= relevanceThreshold && input.gazeTarget != 'unknown';
    sharedState['gate_open'] = isRelevant;
    sharedState['gate_reason'] = isRelevant
        ? 'Salience score $salience satisfies threshold $relevanceThreshold'
        : 'Salience score $salience is below threshold $relevanceThreshold or gaze target is unknown';
    return PipelineResult.success(isRelevant);
  }
}

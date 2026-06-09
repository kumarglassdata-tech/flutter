import 'dart:async';

import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/engines/interaction/interaction_client.dart';
import 'package:smartglass_flutter/core/engines/shared/mappers/request_mappers.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class InteractionSubsystemStep extends PipelineStep<BIEFrame, InteractionResponse> {
  final InteractionClient _client;

  InteractionSubsystemStep(this._client) : super('InteractionSubsystemStep');

  @override
  Future<PipelineResult<InteractionResponse>> execute(
    BIEFrame input,
    Map<String, dynamic> sharedState,
  ) async {
    try {
      final requestPayload = RequestMappers.toInteractionRequest(input);
      final response = await _client.sendInteraction(requestPayload);
      final output = InteractionResponse.fromJson(response);
      sharedState['interaction'] = response;
      sharedState['interaction_output'] = output;
      sharedState['interaction_is_mock'] = false;
      sharedState['interaction_error'] = null;
      return PipelineResult.success(output);
    } catch (e) {
      if (_client.fallbackToMock) {
        final mockOutput = InteractionResponse.mock();
        sharedState['interaction'] = mockOutput.raw;
        sharedState['interaction_output'] = mockOutput;
        sharedState['interaction_is_mock'] = true;
        sharedState['interaction_error'] = e.toString();
        return PipelineResult.success(mockOutput);
      }
      return PipelineResult.failure(e.toString());
    }
  }
}

import 'dart:async';

import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/engines/behavior/behavior_client.dart';
import 'package:smartglass_flutter/core/engines/shared/mappers/request_mappers.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class BehaviourIntentStep extends PipelineStep<ContextEngineOutput, BIEFrame> {
  final BehaviorClient _client;
  final bool _forceMock;

  BehaviourIntentStep(this._client, {bool? forceMock})
      : _forceMock = forceMock ?? EnvConfig.behaviourIntentUrl.isEmpty,
        super('BehaviourIntentStep');

  @override
  Future<PipelineResult<BIEFrame>> execute(
    ContextEngineOutput input,
    Map<String, dynamic> sharedState,
  ) async {
    if (_forceMock) {
      final mockFrame = BIEFrame.mock();
      sharedState['behavior'] = mockFrame.raw;
      sharedState['behavior_output'] = mockFrame;
      sharedState['behavior_is_mock'] = true;
      sharedState['behavior_error'] = 'Forced mock mode (BE_URL is empty)';
      return PipelineResult.success(mockFrame);
    }

    try {
      final lat = sharedState['input_lat'] as double? ?? 0.0;
      final lon = sharedState['input_lon'] as double? ?? 0.0;
      final requestPayload = RequestMappers.toBehaviorRequest(input, lat: lat, lon: lon);
      final response = await _client.sendBehavior(requestPayload);
      final defaultGaze = input.topSalientObjects.firstOrNull;
      final output = BIEFrame.fromJson(response, defaultGazeTarget: defaultGaze);
      sharedState['behavior'] = response;
      sharedState['behavior_output'] = output;
      sharedState['behavior_is_mock'] = false;
      sharedState['behavior_error'] = null;
      return PipelineResult.success(output);
    } catch (e) {
      if (_client.fallbackToMock) {
        final mockOutput = BIEFrame.mock();
        sharedState['behavior'] = mockOutput.raw;
        sharedState['behavior_output'] = mockOutput;
        sharedState['behavior_is_mock'] = true;
        sharedState['behavior_error'] = e.toString();
        return PipelineResult.success(mockOutput);
      }
      return PipelineResult.failure(e.toString());
    }
  }
}

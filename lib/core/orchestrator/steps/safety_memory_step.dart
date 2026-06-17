import 'dart:async';

import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/engines/memory/memory_client.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class SafetyMemoryStep extends PipelineStep<BIEFrame, MemoryResponse> {
  final MemoryClient _client;
  final bool _forceMock;

  SafetyMemoryStep(this._client, {bool? forceMock})
      : _forceMock = forceMock ?? EnvConfig.safetyMemoryUrl.isEmpty,
        super('SafetyMemoryStep');

  @override
  Future<PipelineResult<MemoryResponse>> execute(
    BIEFrame input,
    Map<String, dynamic> sharedState,
  ) async {
    if (_forceMock) {
      final mockResponse = MemoryResponse.mock();
      sharedState['memory'] = mockResponse.raw;
      sharedState['memory_output'] = mockResponse;
      sharedState['memory_is_mock'] = true;
      sharedState['memory_error'] = 'Forced mock mode (MEMORY_URL is empty)';
      return PipelineResult.success(mockResponse);
    }

    try {
      // 1. Recall memory — query by gaze target
      final recallPayload = {
        'operation': 'RECALL',
        'query': input.gazeTarget,
        'top_k': 3,
        'confidence_threshold': 0.4,
      };
      final recallResponse = await _client.recallMemory(recallPayload);

      // 2. Store current interaction in background (non-blocking)
      final storePayload = {
        'operation': 'STORE',
        'content': '${input.intent} on ${input.gazeTarget}',
        'memory_type': 'interaction',
      };
      unawaited(_client.storeMemory(storePayload).catchError((_) {
        return <String, dynamic>{};
      }));

      final output = MemoryResponse.fromJson(recallResponse);
      sharedState['memory'] = recallResponse;
      sharedState['memory_output'] = output;
      sharedState['memory_is_mock'] = false;
      sharedState['memory_error'] = null;
      return PipelineResult.success(output);
    } catch (e) {
      if (_client.fallbackToMock) {
        final mockOutput = MemoryResponse.mock();
        sharedState['memory'] = mockOutput.raw;
        sharedState['memory_output'] = mockOutput;
        sharedState['memory_is_mock'] = true;
        sharedState['memory_error'] = e.toString();
        return PipelineResult.success(mockOutput);
      }
      return PipelineResult.failure(e.toString());
    }
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/engines/context/context_client.dart';
import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class ContextEngineStep extends PipelineStep<UnifiedInput, ContextEngineOutput> {
  final ContextClient _client;

  ContextEngineStep(this._client) : super('ContextEngineStep');

  @override
  Future<PipelineResult<ContextEngineOutput>> execute(
    UnifiedInput input,
    Map<String, dynamic> sharedState,
  ) async {

    final imageBytes = input.imageBytes ?? Uint8List(0);
    final audioLevel = 0.0; // No easy way to get audio level from bytes directly here without decoding
    final lat = input.latitude ?? 0.0;
    final lon = input.longitude ?? 0.0;

    try {
      final response = await _client.sendContext(
        imageBytes: imageBytes,
        audioFeatures: [audioLevel],
        latitude: lat,
        longitude: lon,
      );
      final output = ContextEngineOutput.fromJson(response);
      sharedState['context'] = response;
      sharedState['context_output'] = output;
      sharedState['context_is_mock'] = false;
      sharedState['context_error'] = null;
      return PipelineResult.success(output);
    } catch (e) {
      if (_client.fallbackToMock) {
        final mockOutput = ContextEngineOutput.mock();
        sharedState['context'] = mockOutput.raw;
        sharedState['context_output'] = mockOutput;
        sharedState['context_is_mock'] = true;
        sharedState['context_error'] = e.toString();
        return PipelineResult.success(mockOutput);
      }
      return PipelineResult.failure(e.toString());
    }
  }
}

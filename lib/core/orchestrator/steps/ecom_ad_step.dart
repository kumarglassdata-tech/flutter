import 'dart:async';

import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/engines/ecom/ecom_client.dart';
import 'package:smartglass_flutter/core/engines/shared/mappers/request_mappers.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class EcomAdStep extends PipelineStep<BIEFrame, EcomAdResponse> {
  final EcomClient _client;

  EcomAdStep(this._client) : super('EcomAdStep');

  @override
  Future<PipelineResult<EcomAdResponse>> execute(
    BIEFrame input,
    Map<String, dynamic> sharedState,
  ) async {
    try {
      final requestPayload = RequestMappers.toEcomRequest(input);
      final response = await _client.queryEcom(requestPayload);
      final output = EcomAdResponse.fromJson(response);
      sharedState['ecom'] = response;
      sharedState['ecom_output'] = output;
      sharedState['ecom_is_mock'] = false;
      sharedState['ecom_error'] = null;
      return PipelineResult.success(output);
    } catch (e) {
      if (_client.fallbackToMock) {
        final mockOutput = EcomAdResponse.mock();
        sharedState['ecom'] = mockOutput.raw;
        sharedState['ecom_output'] = mockOutput;
        sharedState['ecom_is_mock'] = true;
        sharedState['ecom_error'] = e.toString();
        return PipelineResult.success(mockOutput);
      }
      return PipelineResult.failure(e.toString());
    }
  }
}

import 'dart:convert';
import 'package:smartglass_flutter/core/models/engine_models.dart';

void main() {
  final json = jsonDecode('{"module":"GD_MYNA_MAS","version":"1.5.0","timestamp":1780708573.1932318,"status":"SUCCESS","latency_ms":7.65,"memory_response":{"status":"SUCCESS","data":[]},"vision_response":{"status":"SUCCESS","detected_objects":[]}}');
  try {
    final output = ContextEngineOutput.fromJson(json);
    print('SUCCESS');
    print('scene: ${output.sceneContext}');
    print('objects: ${output.trackedObjects}');
  } catch (e) {
    print('ERROR: $e');
  }
}

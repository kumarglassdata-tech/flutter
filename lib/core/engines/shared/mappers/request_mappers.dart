import 'dart:convert';
import 'dart:typed_data';
import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class RequestMappers {
  RequestMappers._();

  static Map<String, dynamic> toContextRequest(UnifiedInput input) {
    final imageBytes = input.imageBytes ?? Uint8List(0);
    final audioLevel = 0.0;
    final lat = input.latitude ?? 0.0;
    final lon = input.longitude ?? 0.0;

    return {
      'image': base64Encode(imageBytes),
      'audio': [audioLevel],
      'location': {
        'latitude': lat,
        'longitude': lon,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> toBehaviorRequest(ContextEngineOutput contextOutput, {double? lat, double? lon}) {
    return contextOutput.raw;
  }

  static Map<String, dynamic> toInteractionRequest(BIEFrame bieFrame, {double? lat, double? lon}) {
    return {
      "behavioral_state": bieFrame.intent.isNotEmpty ? bieFrame.intent : "passive_browsing",
      "state_confidence": bieFrame.confidence,
      "relevance_score": bieFrame.salienceScore,
      "hesitation_score": bieFrame.raw['hesitation_score'] ?? 0.0,
      "comparison_detected": bieFrame.raw['comparison_detected'] ?? false,
      "comparison_objects": bieFrame.raw['comparison_objects'] ?? [],
      "gate_open": true,
      "cpu_temp": 32.0,
      "throttled": false
    };
  }

  static Map<String, dynamic> toEcomRequest(BIEFrame bieFrame) {
    return {
      'gaze_target': bieFrame.gazeTarget,
      'intent_scoring': {
        'salience_score': bieFrame.salienceScore,
        'class_name': bieFrame.gazeTarget,
      },
      'top_salient_objects': bieFrame.raw['top_salient_objects'] ?? [
        {
          'object_id': bieFrame.gazeTarget,
          'class_name': bieFrame.gazeTarget,
          'salience_score': bieFrame.salienceScore,
        }
      ],
      'relevance_score': bieFrame.salienceScore,
      'behavioral_state': bieFrame.intent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

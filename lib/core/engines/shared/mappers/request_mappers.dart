import 'dart:convert';
import 'dart:typed_data';
import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class RequestMappers {
  RequestMappers._();

  static Map<String, dynamic> toContextRequest(UnifiedInput input) {
    final imageBytes = input.videoFrame?.bytes ?? Uint8List(0);
    final audioLevel = input.audioChunk?.samples.firstOrNull ?? 0.0;
    final lat = input.location?.latitude ?? 0.0;
    final lon = input.location?.longitude ?? 0.0;
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
    return {
      'context_data': contextOutput.raw,
      'location': {
        'latitude': lat ?? 0.0,
        'longitude': lon ?? 0.0,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> toInteractionRequest(BIEFrame bieFrame) {
    return bieFrame.raw;
  }

  static Map<String, dynamic> toEcomRequest(BIEFrame bieFrame) {
    return {
      'gaze_target': bieFrame.gazeTarget,
      'intent_scoring': {
        'salience_score': bieFrame.salienceScore,
        'class_name': bieFrame.gazeTarget,
      },
      'top_salient_objects': [
        {
          'object_id': 'obj_123',
          'class_name': bieFrame.gazeTarget,
          'salience_score': bieFrame.salienceScore,
        }
      ],
      'relevance_score': bieFrame.salienceScore,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

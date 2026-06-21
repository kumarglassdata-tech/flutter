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

  static Map<String, dynamic> toBehaviorRequest(ContextEngineOutput contextOutput, {double? lat, double? lon, String sessionId = 'wearer_001'}) {
    final raw = Map<String, dynamic>.from(contextOutput.raw);
    
    // The Context Engine now directly returns the exact schema expected by the Behavior Engine.
    // We just ensure session_id is present and inject voice_nlu if available.
    raw['session_id'] = sessionId;
    if (!raw.containsKey('timestamp_ms')) {
      raw['timestamp_ms'] = DateTime.now().millisecondsSinceEpoch;
    }
    
    return raw;
  }

  static Map<String, dynamic> toInteractionRequest(BIEFrame bieFrame, {double? lat, double? lon, String? city, String? country}) {
    final raw = bieFrame.raw;
    final topSalientObjects = raw['top_salient_objects'] ?? [
      {'class_name': bieFrame.gazeTarget, 'salience_score': bieFrame.salienceScore}
    ];

    return {
      'behavioral_state': bieFrame.behavioralState,
      'relevance_score': bieFrame.salienceScore,
      'hesitation_score': raw['hesitation_score'] ?? 0.0,
      'top_salient_objects': topSalientObjects,
      'gate_open': raw['gate_open'] ?? true,
      'cpu_temp': (raw['meta'] as Map?)?['telemetry']?['temperature_c'] ?? 34.0,
      'throttled': (raw['meta'] as Map?)?['telemetry']?['is_throttled'] ?? false,
    };
  }

  static Map<String, dynamic> toEcomRequest(BIEFrame bieFrame) {
    final rawTopSalientObjects = bieFrame.raw['top_salient_objects'];
    final topSalientObjects = rawTopSalientObjects is List
        ? rawTopSalientObjects
        : [
            {
              'class_name': bieFrame.gazeTarget,
              'salience_score': bieFrame.salienceScore,
            }
          ];

    var scoreForBackend = bieFrame.salienceScore;
    if (scoreForBackend >= 0.50) {
      scoreForBackend = 0.85;
    }

    return {
      'timestamp_ms': bieFrame.raw['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch,
      'relevance_score': scoreForBackend,
      'top_salient_objects': topSalientObjects,
    };
  }
}

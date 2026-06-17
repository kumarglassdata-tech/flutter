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

  static Map<String, dynamic> toBehaviorRequest(ContextEngineOutput contextOutput, {double? lat, double? lon, String sessionId = 'wearer_001', Map<String, dynamic>? voiceNlu}) {
    final raw = contextOutput.raw;

    // remap tracked_objects or scene_objects -> scene_objects with class_name as BE expects
    final rawObjects = raw['scene_objects'] as List? ?? raw['tracked_objects'] as List? ?? [];
    final sceneObjects = rawObjects.map((obj) {
      if (obj is Map<String, dynamic>) {
        return {
          'object_id': obj['object_id'] ?? 0,
          'class_name': obj['label'] ?? obj['class_name'] ?? '',
          'bbox_xyxy': obj['bbox_xyxy'] ?? [],
        };
      }
      return obj;
    }).toList();

    return {
      'session_id': sessionId,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'meta': raw['meta'] ?? {
        'frame_reliability': {'gaze_tracker_confidence': 0.95},
        'telemetry': {'temperature_c': 38.5, 'is_throttled': false},
      },
      'gaze_grounding': raw['gaze_grounding'] ?? raw['attention_grounding'] ?? {},
      'scene_objects': sceneObjects,
      'interaction_primitives': raw['interaction_primitives'] ?? {
        'pickup': {'active': false, 'object_id': 0, 'displacement_px': 0.0, 'class_name': ''},
        'product_rotation': {'active': false, 'aspect_ratio_variance': 0.0},
        'shelf_reach': {'active': false, 'arm_y': 0.0},
        'product_comparison': {'active': false, 'compared_items': []},
        'wrist_position': null,
      },
      if (voiceNlu != null) 'voice_nlu': voiceNlu,
      'scene_understanding': raw['scene_understanding'] ?? {'label': contextOutput.sceneContext},
      'activity_understanding': raw['activity_understanding'] ?? {'label': 'browsing'},
    };
  }

  static Map<String, dynamic> toInteractionRequest(BIEFrame bieFrame, {double? lat, double? lon, String? city, String? country}) {
    final raw = bieFrame.raw;
    final topSalientObjects = raw['top_salient_objects'] ?? [
      {'class_name': bieFrame.gazeTarget, 'salience_score': bieFrame.salienceScore}
    ];

    return {
      'timestamp_ms': raw['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch,
      'behavioral_state': bieFrame.behavioralState,
      'state_confidence': bieFrame.stateConfidence,
      'intent_probs': raw['intent_probs'] ?? {},
      'entropy': raw['entropy'] ?? 0.0,
      'top_salient_objects': topSalientObjects,
      'hesitation_score': raw['hesitation_score'] ?? 0.0,
      'comparison_detected': raw['comparison_detected'] ?? false,
      'comparison_objects': raw['comparison_objects'] ?? [],
      'relevance_score': bieFrame.salienceScore,
      'prompt_worthiness': raw['prompt_worthiness'] ?? false,
      'primary_object_dwell_ms': raw['primary_object_dwell_ms'] ?? 0.0,
      'primary_object_revisit_n': raw['primary_object_revisit_n'] ?? 0,
      'gate_open': raw['gate_open'] ?? true,
      'suppress_reason': raw['suppress_reason'],
      'degraded_flags': raw['degraded_flags'] ?? {},
      'emitted': raw['emitted'] ?? true,
      'cpu_temp': (raw['meta'] as Map?)?['telemetry']?['temperature_c'] ?? 32.0,
      'throttled': (raw['meta'] as Map?)?['telemetry']?['is_throttled'] ?? false,
      if (lat != null) 'user_latitude': lat,
      if (lon != null) 'user_longitude': lon,
      if (city != null) 'user_city': city,
      if (country != null) 'user_country': country,
    };
  }

  static Map<String, dynamic> toEcomRequest(BIEFrame bieFrame) {
    return {
      'action_type': 'recommend',
      'salient_objects': [bieFrame.gazeTarget],
      'interaction_mode': 'RECOMMENDATION',
      'relevance_score': bieFrame.salienceScore,
      'gaze_target': bieFrame.gazeTarget,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

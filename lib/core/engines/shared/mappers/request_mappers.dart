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
      'voice_nlu': raw['voice_nlu'] ?? {'rhino_active': false, 'active_intent': '', 'slots': {}},
      'scene_understanding': raw['scene_understanding'] ?? {'label': contextOutput.sceneContext},
      'activity_understanding': raw['activity_understanding'] ?? {'label': 'browsing'},
    };
  }

  static Map<String, dynamic> toInteractionRequest(BIEFrame bieFrame, {double? lat, double? lon, String? city, String? country}) {
    final primitives = bieFrame.raw['interaction_primitives'] as Map? ?? {};
    final pickup = primitives['pickup'] as Map? ?? {};
    final rotation = primitives['product_rotation'] as Map? ?? {};
    final reach = primitives['shelf_reach'] as Map? ?? {};
    final comparison = primitives['product_comparison'] as Map? ?? {};

    return {
      'intent': bieFrame.intent,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'gaze_target': bieFrame.gazeTarget,
      'alignment_score': (bieFrame.raw['gaze_grounding'] as Map?)?['alignment_score'] ?? 0.95,
      'relevance_score': bieFrame.salienceScore,
      'ambient_noise': bieFrame.raw['ambient_noise'] ?? -45.0,
      'pickup_active': pickup['active'] ?? false,
      'rotation_active': rotation['active'] ?? false,
      'reach_active': reach['active'] ?? false,
      'compare_active': comparison['active'] ?? false,
      'compared_items': (comparison['compared_items'] as List? ?? []).map((e) => e.toString()).toList(),
      'cpu_temp': (bieFrame.raw['meta'] as Map?)?['telemetry']?['temperature_c'] ?? 32.0,
      'throttled': (bieFrame.raw['meta'] as Map?)?['telemetry']?['is_throttled'] ?? false,
      'text_input': '',
      if (lat != null) 'latitude': lat,
      if (lon != null) 'longitude': lon,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
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

import 'package:smartglass_flutter/core/config/env_config.dart';

class ContextEngineOutput {
  final String sceneContext;
  final List<String> trackedObjects;
  final List<String> topSalientObjects;
  final Map<String, dynamic> raw;

  ContextEngineOutput({
    required this.sceneContext,
    required this.trackedObjects,
    required this.topSalientObjects,
    required this.raw,
  });

  factory ContextEngineOutput.fromJson(Map<String, dynamic> json) {
    // Scene Context
    var scene = json['scene_understanding']?['label'];
    if (scene == null) {
      final sceneVal = json['scene'] ?? json['scene_context'] ?? json['gps_response']?['hazard_detection']?['zone_name'] ?? 'unknown';
      scene = sceneVal is Map ? (sceneVal['scene_label'] ?? 'unknown') : sceneVal.toString();
    }

    // Tracked Objects
    final List<String> objects = [];
    final rawObjects = json['scene_objects'] ?? json['results']?['vision']?['objects'] ?? json['detected_objects'] ?? json['tracked_objects'];
    if (rawObjects is List) {
      for (var item in rawObjects) {
        if (item is Map) {
          objects.add((item['class_name'] ?? item['class'] ?? item['label'] ?? item['name'] ?? item['object_name'] ?? '').toString());
        } else {
          objects.add(item.toString());
        }
      }
    }

    // Salient Objects / Gaze Grounding
    final List<String> salient = [];
    final groundedTarget = json['gaze_grounding']?['grounded_target'];
    if (groundedTarget != null && groundedTarget != 'unknown') {
      salient.add(groundedTarget.toString());
    }

    final rawSalient = json['top_salient_objects'] ?? json['product_salience'];
    if (rawSalient is List) {
      for (var item in rawSalient) {
        if (item is Map) {
          salient.add((item['class'] ?? item['label'] ?? item['class_name'] ?? item['object_id'] ?? '').toString());
        } else {
          salient.add(item.toString());
        }
      }
    } else if (rawSalient is Map) {
      rawSalient.forEach((key, _) {
        salient.add(key.toString());
      });
    }

    if (salient.isEmpty && objects.isNotEmpty) {
      salient.addAll(objects);
    }

    return ContextEngineOutput(
      sceneContext: scene,
      trackedObjects: objects,
      topSalientObjects: salient,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory ContextEngineOutput.mock() {
    final mockRaw = {
      "scene_context": {
        "scene_label": "User walking in retail store",
        "scene_embedding": [0.1, 0.2, -0.3],
        "scene_confidence": 0.92
      },
      "activity_context": {
        "activity_label": "evaluating_product",
        "activity_confidence": 0.88
      },
      "tracked_objects": [
        {
          "object_id": 102,
          "label": "organic_milk_1l",
          "track_id": "tr_091",
          "bbox_xyxy": [100.0, 150.0, 300.0, 450.0],
          "confidence": 0.94
        }
      ],
      "product_salience": {
        "102": 0.925
      },
      "attention_grounding": {
        "attention_target": "organic_milk_1l",
        "attention_confidence": 0.91
      },
      "hand_object_events": {
        "event_type": "pickup",
        "object_id": 102,
        "confidence": 0.89
      },
      "shelf_reach_events": {
        "reach_detected": true,
        "confidence": 0.87
      },
      "motion_state": {
        "movement_type": "standing",
        "motion_stability": 0.95
      },
      "transition_events": {
        "from_object_id": 0,
        "to_object_id": 102,
        "timestamp_ms": 1717320000000
      },
      "interaction_context_window": {
        "recent_targets": ["organic_milk_1l"],
        "revisit_count": 2,
        "total_dwell_ms": 4200.5
      },
      "context_metadata": {
        "overall_confidence": 0.93,
        "missing_modalities": [],
        "degraded_modes": []
      }
    };
    return ContextEngineOutput.fromJson(mockRaw);
  }
}

class BIEFrame {
  final String intent;
  final double confidence;
  final String gazeTarget;
  final double salienceScore;
  final Map<String, dynamic> raw;

  BIEFrame({
    required this.intent,
    required this.confidence,
    required this.gazeTarget,
    required this.salienceScore,
    required this.raw,
  });

  factory BIEFrame.fromJson(Map<String, dynamic> json, {String? defaultGazeTarget}) {
    var intent = json['behavioral_state'] ?? json['intent'] ?? json['voice_nlu']?['active_intent'] ?? 'unknown';
    final confidence = (json['state_confidence'] ?? json['confidence'] ?? 0.0).toDouble();
    
    // Gaze target is now typically within top_salient_objects or gaze_grounding
    var gazeTarget = json['gaze_grounding']?['grounded_target'] ?? 'unknown';
    if (gazeTarget == 'unknown') {
      final salient = json['top_salient_objects'];
      if (salient is List && salient.isNotEmpty) {
        gazeTarget = salient.first['class_name']?.toString() ?? 'unknown';
      }
    }
    
    if (gazeTarget == 'unknown' && defaultGazeTarget != null) {
      gazeTarget = defaultGazeTarget;
    }

    var salience = (json['relevance_score'] ?? 0.0).toDouble();
    if (salience == 0.0) {
      final salient = json['top_salient_objects'];
      if (salient is List && salient.isNotEmpty) {
        salience = (salient.first['salience_score'] ?? 0.0).toDouble();
      }
    }
    // Do NOT apply a hardcoded fallback — let the real BE relevance_score drive the gate

    return BIEFrame(
      intent: intent,
      confidence: confidence,
      gazeTarget: gazeTarget,
      salienceScore: salience,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory BIEFrame.mock() {
    final mockRaw = {
      "timestamp_ms": 1717320000000,
      "meta": {
        "frame_reliability": {
          "gaze_tracker_confidence": 0.95
        },
        "telemetry": {
          "temperature_c": 38.5,
          "is_throttled": false
        }
      },
      "gaze_grounding": {
        "grounded_target": "organic_milk_1l",
        "alignment_score": 0.88,
        "spatial_proximity_px": 42.5
      },
      "interaction_primitives": {
        "pickup": {
          "active": true,
          "object_id": 102,
          "displacement_px": 125.0,
          "class_name": "organic_milk_1l"
        },
        "product_rotation": {
          "active": true,
          "aspect_ratio_variance": 0.18
        },
        "shelf_reach": {
          "active": false,
          "arm_y": 0.0
        },
        "product_comparison": {
          "active": false,
          "compared_items": []
        }
      },
      "voice_nlu": {
        "rhino_active": true,
        "active_intent": "queryProduct",
        "slots": {
          "product_name": "organic_milk_1l",
          "attribute": "price"
        }
      },
      "scene_understanding": {
        "label": "shelf_b"
      },
      "activity_understanding": {
        "label": "evaluating"
      }
    };
    return BIEFrame.fromJson(mockRaw);
  }
}

class BCPPayload {
  final double relevanceScore;
  final bool gateOpen;
  final String behavioralState;
  final double entropy;
  final double hesitationScore;
  final double stateConfidence;
  final Map<String, dynamic> stateProbabilities;
  final double intentScore;

  BCPPayload({
    required this.relevanceScore,
    required this.gateOpen,
    required this.behavioralState,
    required this.entropy,
    required this.hesitationScore,
    required this.stateConfidence,
    required this.stateProbabilities,
    required this.intentScore,
  });

  factory BCPPayload.fromJson(Map<String, dynamic> json) {
    final entropy = (json['entropy'] ?? 0.0).toDouble();
    final hesitationScore = (json['hesitation_score'] ?? 0.0).toDouble();
    final stateConfidence = (json['state_confidence'] ?? 0.0).toDouble();
    final stateProbabilities = (json['state_probabilities'] ?? json['intent_probs']) as Map<String, dynamic>? ?? {};

    // Calculate commerce score
    double commerceScore = 0.0;
    if (stateProbabilities.isNotEmpty) {
      commerceScore = (stateProbabilities['product_comparison'] ?? 0.0).toDouble() +
          (stateProbabilities['purchase_consideration'] ?? 0.0).toDouble() +
          (stateProbabilities['assistance_seeking'] ?? 0.0).toDouble();
    } else {
      // Fallback if full probabilities aren't provided
      final state = json['behavioral_state'] ?? 'idle';
      if (state == 'product_comparison' || state == 'purchase_consideration' || state == 'assistance_seeking') {
        commerceScore = stateConfidence;
      }
    }

    // Intent score formula: 0.5 * commerce_score + 0.3 * (1 - min(H, 1.6) / 1.6) + 0.2 * hesitation_score
    final hMin = entropy > 1.6 ? 1.6 : entropy;
    final intentScore = (0.5 * commerceScore) + (0.3 * (1.0 - (hMin / 1.6))) + (0.2 * hesitationScore);

    return BCPPayload(
      relevanceScore: (json['relevance_score'] ?? intentScore).toDouble(),
      gateOpen: json['gate_open'] ?? false,
      behavioralState: json['behavioral_state'] ?? 'idle',
      entropy: entropy,
      hesitationScore: hesitationScore,
      stateConfidence: stateConfidence,
      stateProbabilities: stateProbabilities,
      intentScore: intentScore,
    );
  }
}

class InteractionResponse {
  final String dialogueMode;
  final String lastUtterance;
  final String llmGateStatus;
  final BCPPayload bcp;
  final Map<String, dynamic> raw;
  final bool isAssistantGenerating;

  InteractionResponse({
    required this.dialogueMode,
    required this.lastUtterance,
    required this.llmGateStatus,
    required this.bcp,
    required this.raw,
    this.isAssistantGenerating = false,
  });

  factory InteractionResponse.fromJson(Map<String, dynamic> json) {
    final voiceNlu = json['voice_assistant_response'] ?? json['voice_nlu'];
    final dialogueMode = json['dialogue_mode'] ?? (voiceNlu is Map ? (voiceNlu['intent'] ?? 'chat') : 'chat');
    
    String utterance = '';
    final dialogueState = json['dialogue_state'];
    if (dialogueState is Map && dialogueState['last_utterance'] != null) {
      utterance = dialogueState['last_utterance'].toString();
    } else if (json['last_utterance'] != null) {
      utterance = json['last_utterance'].toString();
    } else if (voiceNlu is Map && voiceNlu['generated_response'] != null) {
      utterance = voiceNlu['generated_response'].toString();
    }

    final llmGateStatus = json['llm_gate_status'] ?? ((voiceNlu is Map && voiceNlu['generated_response'] != null) ? 'open' : 'closed');
    return InteractionResponse(
      dialogueMode: dialogueMode,
      lastUtterance: utterance,
      llmGateStatus: llmGateStatus,
      bcp: BCPPayload.fromJson(json['bcp'] ?? {}),
      raw: json,
      isAssistantGenerating: json['is_assistant_generating'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory InteractionResponse.mock() {
    final mockRaw = {
      "dialogue_mode": "recommendation_eligible -> RECOMMENDATION",
      "last_utterance": "That organic_milk_1l is highly rated! Would you like to check details?",
      "llm_gate_status": "BYPASSED",
      "escalation_eligibility": true,
      "compute_pressure": 0.0,
      "local_mic_transcript": "hey myna is this healthy",
      "bcp": {
        "timestamp_ms": 1717320000000,
        "behavioral_state": "purchase_consideration",
        "state_confidence": 0.8452,
        "entropy": 0.4215,
        "top_salient_objects": [
          { "object_id": 102, "class_name": "organic_milk_1l", "salience_score": 0.925 }
        ],
        "hesitation_score": 0.75,
        "comparison_detected": false,
        "comparison_objects": [],
        "relevance_score": 0.885,
        "prompt_worthiness": true,
        "primary_object_dwell_ms": 4200.5,
        "primary_object_revisit_n": 2,
        "gate_open": true,
        "suppress_reason": null,
        "degraded_flags": { "gaze": false, "hand": false, "tracking": false },
        "emitted": true,
        "cpu_temp": 32.0,
        "throttled": false,
        "voice_nlu": {
          "rhino_active": true,
          "active_intent": "queryProduct",
          "slots": { "user_query": "is this healthy", "product_name": "organic_milk_1l" }
        }
      }
    };
    return InteractionResponse.fromJson(mockRaw);
  }
}

class EcomAdProduct {
  final String id;
  final String name;
  final double price;
  final String imageUrl;

  EcomAdProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  factory EcomAdProduct.fromJson(Map<String, dynamic> json) {
    double parsedPrice = 0.0;
    if (json['price_val'] != null) {
      parsedPrice = (json['price_val'] as num).toDouble();
    } else if (json['price'] != null) {
      if (json['price'] is num) {
        parsedPrice = (json['price'] as num).toDouble();
      } else if (json['price'] is String) {
        final cleaned = (json['price'] as String).replaceAll(RegExp(r'[^\d.]'), '');
        parsedPrice = double.tryParse(cleaned) ?? 0.0;
      }
    }

    var idVal = json['id']?.toString() ?? json['link']?.toString() ?? json['action_link']?.toString() ?? '';
    if (idVal.contains('url=')) {
      try {
        final uri = Uri.parse(idVal);
        final directUrl = uri.queryParameters['url'];
        if (directUrl != null && directUrl.isNotEmpty) {
          idVal = directUrl;
        }
      } catch (_) {}
    } 

    if (idVal.isNotEmpty && !idVal.startsWith('http')) {
      final base = EnvConfig.actionHubBuyUrl.endsWith('/buy') 
          ? EnvConfig.actionHubBuyUrl.replaceAll('/buy', '') 
          : EnvConfig.actionHubBuyUrl;
      if (idVal.startsWith('/')) {
        idVal = '$base$idVal';
      } else if (idVal.startsWith('myna-ah')) {
        idVal = 'https://$idVal';
      } else if (idVal.startsWith('buy/')) {
        idVal = '$base/$idVal';
      } else {
        idVal = '$base/buy/$idVal'; 
      }
    }

    return EcomAdProduct(
      id: idVal,
      name: json['title']?.toString() ??
          json['name']?.toString() ??
          json['product']?.toString() ??
          json['platform']?.toString() ??
          '',
      price: parsedPrice,
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_val': price,
      'image_url': imageUrl,
    };
  }
}

class EcomAdResponse {
  final String status;
  final List<EcomAdProduct> suggestions;
  final Map<String, dynamic> raw;

  EcomAdResponse({
    required this.status,
    required this.suggestions,
    required this.raw,
  });

  factory EcomAdResponse.fromJson(Map<String, dynamic> json) {
    final parsed = <EcomAdProduct>[];
    
    if (json['ad_content'] != null) {
      final ad = json['ad_content'] as Map<String, dynamic>;
      parsed.add(EcomAdProduct.fromJson(ad));
    }

    final list = json['suggestions'] ?? json['recommendations'] ?? json['comparison_data'] ?? json['mall_feed'] ?? [];
    for (final item in (list as List)) {
      final map = item as Map<String, dynamic>;
      final product = EcomAdProduct.fromJson(map);
      if (!parsed.any((p) => p.id == product.id)) {
        parsed.add(product);
      }
    }

    // Fallback: if it's a flat Action Hub payload
    if (parsed.isEmpty && (json.containsKey('product_url') || json.containsKey('link') || json.containsKey('url') || json.containsKey('image_url') || json.containsKey('image'))) {
      parsed.add(EcomAdProduct.fromJson(json));
    }

    return EcomAdResponse(
      status: json['status']?.toString() ?? 'success',
      suggestions: parsed,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory EcomAdResponse.mock() {
    final mockRaw = {
      "status": "success",
      "suggestions": [
        {
          "id": "https://www.amazon.in/Lenovo-V15-Lifetime-Validity-Warranty/dp/B0CL7CMTXS",
          "link": "https://www.amazon.in/Lenovo-V15-Lifetime-Validity-Warranty/dp/B0CL7CMTXS",
          "name": "Lenovo V15 G4 AMD Athlon Laptop",
          "price": 42999.00,
          "image_url": "https://m.media-amazon.com/images/I/61AccNkmFFL._AC_UY218_.jpg"
        },
        {
          "id": "https://www.flipkart.com/search?q=laptop",
          "link": "https://www.flipkart.com/search?q=laptop",
          "name": "Laptop - F-Assured Best Seller",
          "price": 280.00,
          "image_url": "https://upload.wikimedia.org/wikipedia/en/thumb/7/7a/Flipkart_logo.svg/100px-Flipkart_logo.svg.png"
        }
      ]
    };
    return EcomAdResponse.fromJson(mockRaw);
  }
}

class MemoryResponse {
  final String status;
  final String recallData;
  final Map<String, dynamic> raw;

  MemoryResponse({
    required this.status,
    required this.recallData,
    required this.raw,
  });

  factory MemoryResponse.fromJson(Map<String, dynamic> json) {
    var recallText = '';
    final memories = json['semantic_memories'] ?? json['memories'] ?? (json['memory_response'] as Map?)?['semantic_memories'];
    if (memories is List) {
      recallText = memories.map((m) {
        if (m is Map) {
          return "${m['memory_type'] ?? m['type'] ?? ''}: ${m['content'] ?? m['text'] ?? ''}";
        }
        return m.toString();
      }).join(', ');
    } else if (memories is Map) {
      recallText = "${memories['memory_type'] ?? memories['type'] ?? ''}: ${memories['content'] ?? memories['text'] ?? ''}";
    } else {
      recallText = (json['recall_data'] ?? json['data'] ?? '').toString();
    }
    return MemoryResponse(
      status: json['status'] ?? 'success',
      recallData: recallText,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory MemoryResponse.mock() {
    final mockRaw = {
      "status": "success",
      "semantic_memories": [
        {
          "memory_id": "mem_4a8f9",
          "content": "user allergic to cups",
          "memory_type": "allergy",
          "timestamp_ms": 1747215401200,
          "relevance_score": 0.95
        }
      ],
      "retrieval_metadata": {
        "query_embedding": [0.12, -0.08, 0.44],
        "top_k_returned": 3,
        "search_latency_ms": 45
      }
    };
    return MemoryResponse.fromJson(mockRaw);
  }
}

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
      final sceneVal = json['scene'] ??
          json['scene_context'] ??
          json['gps_response']?['hazard_detection']?['zone_name'] ??
          'unknown';
      scene = sceneVal is Map
          ? (sceneVal['scene_label'] ?? 'unknown')
          : sceneVal.toString();
    }

    // Tracked Objects
    final List<String> objects = [];
    final rawObjects = json['scene_objects'] ??
        json['results']?['vision']?['objects'] ??
        json['detected_objects'] ??
        json['tracked_objects'];
    if (rawObjects is List) {
      for (var item in rawObjects) {
        if (item is Map) {
          objects.add((item['class_name'] ??
                  item['class'] ??
                  item['label'] ??
                  item['name'] ??
                  item['object_name'] ??
                  '')
              .toString());
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
          salient.add((item['class'] ??
                  item['label'] ??
                  item['class_name'] ??
                  item['object_id'] ??
                  '')
              .toString());
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
      "product_salience": {"102": 0.925},
      "attention_grounding": {
        "attention_target": "organic_milk_1l",
        "attention_confidence": 0.91
      },
      "hand_object_events": {
        "event_type": "pickup",
        "object_id": 102,
        "confidence": 0.89
      },
      "shelf_reach_events": {"reach_detected": true, "confidence": 0.87},
      "motion_state": {"movement_type": "standing", "motion_stability": 0.95},
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
  final String behavioralState; // e.g. "product_interest", "comparison"
  final double
      stateConfidence; // confidence in the behavioral state classification
  final String gazeTarget;
  final double salienceScore; // relevance_score from BE — drives the gate
  final double intentScore; // computed commerce intent score from BCPPayload
  final Map<String, dynamic> raw;

  // keep legacy getters so nothing else breaks
  String get intent => behavioralState;
  double get confidence => stateConfidence;

  BIEFrame({
    required this.behavioralState,
    required this.stateConfidence,
    required this.gazeTarget,
    required this.salienceScore,
    required this.intentScore,
    required this.raw,
  });

  factory BIEFrame.fromJson(Map<String, dynamic> json,
      {String? defaultGazeTarget}) {
    final behavioralState = (json['behavioral_state'] ??
            json['intent'] ??
            json['voice_nlu']?['active_intent'] ??
            'unknown')
        .toString();
    final stateConfidence =
        (json['state_confidence'] ?? json['confidence'] ?? 0.0).toDouble();

    var gazeTarget =
        json['gaze_grounding']?['grounded_target']?.toString() ?? 'unknown';
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

    // No more local edge calculations - trust the backend
    final intentScore = salience;

    return BIEFrame(
      behavioralState: behavioralState,
      stateConfidence: stateConfidence,
      gazeTarget: gazeTarget,
      salienceScore: salience,
      intentScore: intentScore,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory BIEFrame.mock() {
    final mockRaw = {
      "timestamp_ms": 1717320000000,
      "meta": {
        "frame_reliability": {"gaze_tracker_confidence": 0.95},
        "telemetry": {"temperature_c": 38.5, "is_throttled": false}
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
        "product_rotation": {"active": true, "aspect_ratio_variance": 0.18},
        "shelf_reach": {"active": false, "arm_y": 0.0},
        "product_comparison": {"active": false, "compared_items": []}
      },
      "voice_nlu": {
        "rhino_active": true,
        "active_intent": "queryProduct",
        "slots": {"product_name": "organic_milk_1l", "attribute": "price"}
      },
      "scene_understanding": {"label": "shelf_b"},
      "activity_understanding": {"label": "evaluating"},
      "intent_probs": {
        "passive_browsing": 0.05,
        "product_interest": 0.60,
        "comparison": 0.05,
        "purchase_consideration": 0.25,
        "assistance_seeking": 0.05
      },
      "entropy": 0.42,
      "hesitation_score": 0.75,
      "relevance_score": 0.885
    };
    return BIEFrame.fromJson(mockRaw);
  }
}

class BCPPayload {
  final double entropy;
  final double hesitationScore;
  final double stateConfidence;
  final Map<String, dynamic> stateProbabilities;
  final double intentScore;
  final double relevanceScore;
  final bool gateOpen;
  final String behavioralState;

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
    final stateProbabilities = (json['state_probabilities'] ??
            json['intent_probs']) as Map<String, dynamic>? ??
        {};

    final intentScore = (json['relevance_score'] ?? 0.0).toDouble();
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
    final dialogueMode = json['dialogue_mode'] ??
        (voiceNlu is Map ? (voiceNlu['intent'] ?? 'chat') : 'chat');

    String utterance = '';
    final dialogueState = json['dialogue_state'];
    if (dialogueState is Map && dialogueState['last_utterance'] != null) {
      utterance = dialogueState['last_utterance'].toString();
    } else if (json['last_utterance'] != null) {
      utterance = json['last_utterance'].toString();
    } else if (voiceNlu is Map && voiceNlu['generated_response'] != null) {
      utterance = voiceNlu['generated_response'].toString();
    }

    final llmGateStatus = json['llm_gate_status'] ??
        ((voiceNlu is Map && voiceNlu['generated_response'] != null)
            ? 'open'
            : 'closed');
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
      "last_utterance":
          "That organic_milk_1l is highly rated! Would you like to check details?",
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
          {
            "object_id": 102,
            "class_name": "organic_milk_1l",
            "salience_score": 0.925
          }
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
        "degraded_flags": {"gaze": false, "hand": false, "tracking": false},
        "emitted": true,
        "cpu_temp": 32.0,
        "throttled": false,
        "voice_nlu": {
          "rhino_active": true,
          "active_intent": "queryProduct",
          "slots": {
            "user_query": "is this healthy",
            "product_name": "organic_milk_1l"
          }
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
  final String? headline;
  final String? delivery;
  final double? rating;
  final String? offer;
  final String? platform;
  final String? category;
  final double? finalScore;

  EcomAdProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.headline,
    this.delivery,
    this.rating,
    this.offer,
    this.platform,
    this.category,
    this.finalScore,
  });

  factory EcomAdProduct.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['ad_content'] as Map<String, dynamic>? ?? rawJson;
    double parsedPrice = 0.0;
    if (json['price_val'] != null) {
      parsedPrice = (json['price_val'] as num).toDouble();
    } else if (json['price'] != null) {
      if (json['price'] is num) {
        parsedPrice = (json['price'] as num).toDouble();
      } else if (json['price'] is String) {
        final cleaned =
            (json['price'] as String).replaceAll(RegExp(r'[^\d.]'), '');
        parsedPrice = double.tryParse(cleaned) ?? 0.0;
      }
    }

    var idVal = json['id']?.toString() ??
        json['product_url']?.toString() ??
        json['url']?.toString() ??
        json['redirect_url']?.toString() ??
        json['redirect']?.toString() ??
        json['link']?.toString() ??
        json['action_link']?.toString() ??
        '';
    if (idVal.contains('url=')) {
      try {
        final uri = Uri.parse(idVal);
        final directUrl = uri.queryParameters['url'] ??
            uri.queryParameters['redirect'] ??
            uri.queryParameters['target'];
        if (directUrl != null && directUrl.isNotEmpty) {
          idVal = directUrl;
        }
      } catch (_) {}
    }

    if (idVal == '#' || idVal == 'N/A' || idVal == 'null') {
      idVal = '';
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
          json['product_name']?.toString() ??
          json['label']?.toString() ??
          (idVal.isNotEmpty ? 'Product link' : ''),
      price: parsedPrice,
      imageUrl: json['image_url']?.toString() ??
          json['image']?.toString() ??
          json['thumbnail']?.toString() ??
          json['thumbnail_url']?.toString() ??
          '',
      headline: json['headline']?.toString(),
      delivery: json['delivery']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      offer: json['offer']?.toString(),
      platform: json['platform']?.toString(),
      category: json['category']?.toString(),
      finalScore: (json['final_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_val': price,
      'image_url': imageUrl,
      'delivery': delivery,
      'rating': rating,
      'offer': offer,
      'platform': platform,
      'category': category,
      'final_score': finalScore,
    };
  }
}

class PlatformAnalytics {
  final String platform;
  final String adSpend;
  final int clicks;
  final String ctr;
  final int impressions;
  final String revenue;
  final String roas;
  final String roi;

  PlatformAnalytics({
    required this.platform,
    required this.adSpend,
    required this.clicks,
    required this.ctr,
    required this.impressions,
    required this.revenue,
    required this.roas,
    required this.roi,
  });

  factory PlatformAnalytics.fromJson(String platform, Map<String, dynamic> json) {
    return PlatformAnalytics(
      platform: platform,
      adSpend: json['ad_spend']?.toString() ?? '₹0.00',
      clicks: json['clicks'] ?? 0,
      ctr: json['ctr']?.toString() ?? '0.0%',
      impressions: json['impressions'] ?? 0,
      revenue: json['revenue']?.toString() ?? '₹0.00',
      roas: json['roas']?.toString() ?? '0.00x',
      roi: json['roi']?.toString() ?? '0.0%',
    );
  }
}

class AnalyzeResponse {
  final List<PlatformAnalytics> platforms;
  final int suppressions;

  AnalyzeResponse({required this.platforms, required this.suppressions});

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final platformsJson = json['platforms'] as Map<String, dynamic>? ?? {};
    final platformsList = platformsJson.entries.map((e) => PlatformAnalytics.fromJson(e.key, e.value)).toList();
    return AnalyzeResponse(
      platforms: platformsList,
      suppressions: json['suppressions'] ?? 0,
    );
  }
}

class LifeBalanceResponse {
  final int score;
  final Map<String, double> breakdown;
  final List<String> categories;
  final List<double> actualData;
  final List<double> recommendedData;
  final String primaryNotification;

  LifeBalanceResponse({
    required this.score,
    required this.breakdown,
    required this.categories,
    required this.actualData,
    required this.recommendedData,
    required this.primaryNotification,
  });

  factory LifeBalanceResponse.fromJson(Map<String, dynamic> json) {
    final bd = json['breakdown'] as Map<String, dynamic>? ?? {};
    final breakdownMap = bd.map((k, v) => MapEntry(k, double.tryParse(v.toString().replaceAll('%', '')) ?? 0.0));
    
    final chartData = json['chart_data'] as Map<String, dynamic>? ?? {};
    final categories = (chartData['categories'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final actual = (chartData['actual'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final recommended = (chartData['recommended'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    final notifs = json['notifications'] as List? ?? [];
    String notification = "Great job maintaining a healthy life balance!";
    if (notifs.isNotEmpty && notifs.first is Map) {
      notification = notifs.first['message']?.toString() ?? notification;
    }

    return LifeBalanceResponse(
      score: json['life_balance_score'] ?? 0,
      breakdown: breakdownMap,
      categories: categories,
      actualData: actual,
      recommendedData: recommended,
      primaryNotification: notification,
    );
  }
}

class EcomAdResponse {
  final String status;
  final List<EcomAdProduct> suggestions;
  final AnalyzeResponse? analyzeData;
  final LifeBalanceResponse? lifeBalanceData;
  final Map<String, dynamic> raw;

  EcomAdResponse({
    required this.status,
    required this.suggestions,
    this.analyzeData,
    this.lifeBalanceData,
    required this.raw,
  });

  factory EcomAdResponse.fromJson(Map<String, dynamic> json) {
    final parsed = <EcomAdProduct>[];

    if (json['ad_content'] != null) {
      final ad = json['ad_content'] as Map<String, dynamic>;
      parsed.add(EcomAdProduct.fromJson(ad));
    }

    final list = json['suggestions'] ??
        json['recommendations'] ??
        json['products'] ??
        json['product_links'] ??
        json['links'] ??
        json['buy_links'] ??
        json['comparison_data'] ??
        json['mall_feed'] ??
        [];
    if (list is List) {
      for (final item in list) {
        final map = item is Map<String, dynamic>
            ? item
            : item is Map
                ? Map<String, dynamic>.from(item)
                : {'link': item.toString()};
        final product = EcomAdProduct.fromJson(map);
        if (!parsed.any((p) => p.id == product.id)) {
          parsed.add(product);
        }
      }
    }

    // Fallback: if it's a flat Action Hub payload
    if (parsed.isEmpty &&
        (json.containsKey('product_url') ||
            json.containsKey('link') ||
            json.containsKey('url') ||
            json.containsKey('redirect_url') ||
            json.containsKey('redirect') ||
            json.containsKey('action_link') ||
            json.containsKey('image_url') ||
            json.containsKey('image'))) {
      parsed.add(EcomAdProduct.fromJson(json));
    }
    
    // Attempt to parse nested analyze and lifebalance if they were injected by the client
    AnalyzeResponse? analyze;
    if (json.containsKey('analyze_response')) {
      analyze = AnalyzeResponse.fromJson(json['analyze_response']);
    }
    
    LifeBalanceResponse? lifeBalance;
    if (json.containsKey('lifebalance_response')) {
      lifeBalance = LifeBalanceResponse.fromJson(json['lifebalance_response']);
    }

    return EcomAdResponse(
      status: json['status']?.toString() ?? 'success',
      suggestions: parsed,
      analyzeData: analyze,
      lifeBalanceData: lifeBalance,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;

  factory EcomAdResponse.mock() {
    final mockRaw = {"status": "success", "suggestions": []};
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
    final memories = json['semantic_memories'] ??
        json['memories'] ??
        (json['memory_response'] as Map?)?['semantic_memories'];
    if (memories is List) {
      recallText = memories.map((m) {
        if (m is Map) {
          return "${m['memory_type'] ?? m['type'] ?? ''}: ${m['content'] ?? m['text'] ?? ''}";
        }
        return m.toString();
      }).join(', ');
    } else if (memories is Map) {
      recallText =
          "${memories['memory_type'] ?? memories['type'] ?? ''}: ${memories['content'] ?? memories['text'] ?? ''}";
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

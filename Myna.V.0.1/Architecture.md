# Smart Myna Engine Architecture & Data Flow

This document details the complete integration flow between the Flutter App and the backend AI Engines, including exact JSON payloads and architectural pipelines.

## Architecture at a Glance

The system operates on two independent but intersecting pipelines:

1. **Pipeline 1: WebSocket → MIIS (Interaction Engine)**
   - Voice driven, event-based.
   - Handles ASR (Automatic Speech Recognition), FSM (Finite State Machine), and TTS (Text-to-Speech).
2. **Pipeline 2: REST POST → BE (Behavioral Engine)**
   - Sensor driven (camera, gaze, hand sensors), continuous.
   - Triggers every ~200ms (5fps) per context engine frame.

The Flutter app acts as the **signal aggregator**, taking `voice_nlu` data from MIIS and injecting it into the continuous stream of Behavioral Engine frames.

---

## 1. Context Engine

Processes raw sensory inputs to understand the scene and track objects.

* **POST `/inp`**
  * Submits raw video frames (base64) and GPS coordinates.
* **GET `/predict`**
  * **Payload (Response):**
    ```json
    {
      "timestamp_ms": 1782026014237,
      "session_id": "wearer_001",
      "meta": {
        "frame_reliability": { "gaze_tracker_confidence": 0.4 },
        "telemetry": { "temperature_c": 38.5, "is_throttled": false }
      },
      "gaze_grounding": {
        "grounded_target": "",
        "alignment_score": 0,
        "spatial_proximity_px": 0,
        "gaze_coordinates": { "x": 529, "y": 297 }
      },
      "scene_objects": [],
      "interaction_primitives": {
        "pickup": { "active": false, "object_id": 0, "displacement_px": 0, "class_name": "" },
        "product_rotation": { "active": false, "aspect_ratio_variance": 0 },
        "shelf_reach": { "active": false, "arm_y": 388 },
        "product_comparison": { "active": false, "compared_items": [] },
        "wrist_position": { "x": 888, "y": 388 }
      },
      "scene_understanding": { "label": "indoor home / office (Vision Only)" },
      "activity_understanding": { "label": "browsing" }
    }
    ```

---

## 2. Behavioral Engine (BE)

Analyzes the output from the Context Engine combined with voice data to deduce user behavioral intent.

* **POST `/api/v1/process`**
  * **Payload (Input):** This includes the Context Engine's `predict` output *plus* the `voice_nlu` parameter injected from the Interaction Engine if active.
    ```json
    {
      "timestamp_ms": 1717320000000,
      "meta": {
        "frame_reliability": { "gaze_tracker_confidence": 0.95 },
        "telemetry": { "temperature_c": 38.5, "is_throttled": false }
      },
      "gaze_grounding": {
        "grounded_target": "organic_milk_1l",
        "alignment_score": 0.88,
        "spatial_proximity_px": 42.5
      },
      "interaction_primitives": {
        "pickup": { "active": true, "object_id": 102, "displacement_px": 125.0, "class_name": "organic_milk_1l" },
        "product_rotation": { "active": true, "aspect_ratio_variance": 0.18 },
        "shelf_reach": { "active": false, "arm_y": 0.0 },
        "product_comparison": { "active": false, "compared_items": [] }
      },
      "voice_nlu": {
        "rhino_active": true,
        "active_intent": "queryProduct",
        "slots": { "product_name": "organic_milk_1l", "attribute": "price" }
      },
      "scene_understanding": { "label": "shelf_b" },
      "activity_understanding": { "label": "evaluating" }
    }
    ```
  * **Payload (Output):**
    ```json
    {
      "timestamp_ms": 1717320000000,
      "behavioral_state": "purchase_consideration",
      "state_confidence": 0.8452,
      "intent_probs": {
        "passive_browsing": 0.0102,
        "product_interest": 0.0842,
        "comparison": 0.0604,
        "purchase_consideration": 0.8452,
        "assistance_seeking": 0.0
      },
      "entropy": 0.4215,
      "top_salient_objects": [
        { "object_id": 102, "class_name": "organic_milk_1l", "salience_score": 0.925 },
        { "object_id": 105, "class_name": "regular_milk_1l", "salience_score": 0.380 }
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
      "emitted": true
    }
    ```

---

## 3. Interaction Engine (MIIS) - WebSocket Pipeline

Manages voice dialogue and real-time LLM interaction.

* **Connection:** `ws://host:8001/ws`
* **Set Location:**
  ```json
  { "type": "set_location", "latitude": 17.3850, "longitude": 78.4867, "city": "Hyderabad" }
  ```
* **Audio Streaming:**
  Sends `{ "type": "start_of_speech" }`, followed by raw binary `PCM16` (16kHz, mono) audio chunks, and then `{ "type": "end_of_speech" }`.
* **Incoming Messages:**
  * **`transcript`**: Live caption overlay.
  * **`status` (Crucial):** Contains the fused BCP frame and `voice_nlu` data which Flutter must cache (15s TTL) and inject into Behavioral Engine frames.
    ```json
    {
      "type": "status",
      "dialogue_mode": "recommendation_eligible",
      "last_utterance": "Sure! Adding that bottle to your cart.",
      "llm_gate_status": "OPEN",
      "assistant_speaking": true,
      "bcp": {
        "behavioral_state": "purchase_consideration",
        "voice_nlu": {
          "rhino_active": true,
          "active_intent": "buyProduct",
          "intent_confidence": 1.0,
          "slots": { "product_name": "bottle" }
        }
      }
    }
    ```
  * **`audio_chunk`**: Base64 or binary PCM data for TTS playback.

---

## 4. Ecom Engine (Action Hub)

Handles product recommendations, pricing comparisons, and lifestyle tracking.

* **POST `/inp/`**
  * **Payload:**
    ```json
    {
      "timestamp_ms": 0,
      "relevance_score": 0,
      "top_salient_objects": []
    }
    ```
* **GET `/buy`**
  * **Response:** Contains `ad_content`, `comparison_data`, and `mall_feed` (with ranked items, prices, delivery speeds, and semantic scores).
* **GET `/recommend`**
  * **Response:** Contains `ambient discovery` ad content, and a `mall_feed` with items ranked by Temporal Softmax Act and Epsilon-Greedy Bias Term.
* **GET `/analyze`**
  * **Response:** Ad spend, impressions, CTR, and ROAS across platforms like Amazon, Flipkart, and Zepto.
* **GET `/lifebalance`**
  * **Response:**
    ```json
    {
      "breakdown": { "Family Score": "25%", "Fitness Score": "20%", "Me Time Score": "20%", "Social Balance": "8%", "Work/Study Score": "25%" },
      "life_balance_score": 98,
      "notifications": [ { "message": "Great job maintaining a healthy life balance this week!", "type": "Wellness Notification" } ]
    }
    ```

---

## 5. Safety Memory Engine

Provides safety alerts, geographical awareness, and contextual semantic memory (RAG).

* **GET `/api/release`**
  * **Response:**
    ```json
    {
      "status": "SUCCESS",
      "memory_response": {
        "operation": "RECALL",
        "semantic_memories": [
          { "memory_id": "mem_619cfa...", "content": "i am alergitic to chair", "memory_type": "allergy", "relevance_score": 0.95 },
          { "memory_id": "mem_1cc915...", "content": "remember i am alergitic to peanut", "memory_type": "allergy", "relevance_score": 0.95 }
        ]
      },
      "gps_response": {
        "current_location": { "latitude": 17.385044, "longitude": 78.486671 },
        "hazard_detection": { "restricted_zone": false, "zone_name": "Safe Zone", "risk_level": "LOW", "warning_message": "Area clear." }
      },
      "voice_assistant_response": {
        "intent": "MEMORY_RECALL",
        "generated_response": "No immediate hazards.",
        "tts_enabled": false
      }
    }
    ```

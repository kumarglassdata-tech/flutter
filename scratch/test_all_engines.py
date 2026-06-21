import urllib.request
import json
import base64
import time

URLS = {
    'CE': 'https://myna-ce-dev.glassdata.ai/predict',
    'BE': 'https://myna-be-dev.glassdata.ai/api/v1/process',
    'AH_BUY': 'https://myna-ah-dev.glassdata.ai/buy',
    'AH_REC': 'https://myna-ah-dev.glassdata.ai/recommend',
    'AH_ANALYZE': 'https://myna-ah-dev.glassdata.ai/analyze',
    'SME': 'https://myna-sme-dev.glassdata.ai/api/release'
}

def probe_engine(name, url, payload):
    print(f"\n[{name}] Probing {url}")
    print(f"INPUT: {json.dumps(payload)}")
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method='POST')
    
    try:
        start_time = time.time()
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            elapsed = time.time() - start_time
            print(f"OUTPUT (status {response.status}, {elapsed*1000:.1f}ms): {result}")
            return json.loads(result)
    except urllib.error.HTTPError as e:
        print(f"HTTP ERROR: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    # 1. CE (Context Engine)
    ce_payload = {
        "image": base64.b64encode(b'dummy_image_data').decode('utf-8'),
        "audio": [0.0],
        "location": {"latitude": 17.48, "longitude": 78.38},
        "timestamp": int(time.time() * 1000)
    }
    probe_engine('Context Engine', URLS['CE'], ce_payload)
    
    # 2. BE (Behavior Engine)
    be_payload = {
        "session_id": "test_script_001",
        "timestamp_ms": int(time.time() * 1000),
        "top_salient_objects": [{"object_id": 1, "class_name": "laptop", "salience_score": 0.9}],
        "entropy": 0.5,
        "salience_score": 0.9,
        "voice_nlu": {"active_intent": "BUYPRODUCT", "slots": {}}
    }
    probe_engine('Behavior Engine', URLS['BE'], be_payload)
    
    # 3. AH (Action Hub)
    ah_payload = {
        "user_query": "open add",
        "detected_objects": ["laptop"],
        "behavioral_state": "purchase_consideration"
    }
    probe_engine('Action Hub (Buy)', URLS['AH_BUY'], ah_payload)
    probe_engine('Action Hub (Recommend)', URLS['AH_REC'], ah_payload)
    probe_engine('Action Hub (Analyze)', URLS['AH_ANALYZE'], ah_payload)
    
    # 4. SME (Safety Memory Engine)
    sme_payload = {
        "user_id": "test_script_001",
        "context": "Looking at laptop",
        "intent": "BUYPRODUCT"
    }
    probe_engine('Safety Memory Engine', URLS['SME'], sme_payload)

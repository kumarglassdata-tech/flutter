import requests
import json
import time

url = "https://myna-ah-dev.glassdata.ai/buy"

payload = {
    "gaze_target": "organic_milk_1l",
    "intent_scoring": {
        "salience_score": 0.92,
        "class_name": "organic_milk_1l"
    },
    "top_salient_objects": [{"class_name": "organic_milk_1l", "salience_score": 0.92}],
    "relevance_score": 0.92,
    "behavioral_state": "product_interest",
    "timestamp": int(time.time() * 1000)
}

try:
    print(f"Calling {url}...")
    resp = requests.post(url, json=payload, timeout=5)
    print(f"Status Code: {resp.status_code}")
    print(f"Response: {resp.text}")
except Exception as e:
    print(f"Error: {e}")

import urllib.request
import json
import time

url = "https://myna-ah-dev.glassdata.ai/recommend"

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

data = json.dumps(payload).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method='POST')

try:
    with urllib.request.urlopen(req, timeout=10) as response:
        print(f"Status Code: {response.status}")
        print(f"Response: {response.read().decode('utf-8')}")
except Exception as e:
    print(f"Error: {e}")

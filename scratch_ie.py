import urllib.request
import urllib.parse
import json
import base64
import io
from urllib.request import Request, urlopen

body = json.dumps({'audio': 'UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA='}).encode('utf-8')

try:
    req = Request('https://myna-ie-dev.glassdata.ai/process', data=body, headers={'Content-Type': 'application/json'})
    res = urlopen(req)
    print("STATUS", res.getcode())
    print("BODY", res.read().decode())
except urllib.error.HTTPError as e:
    print("STATUS", e.code)
    print("BODY", e.read().decode())

import urllib.request
import urllib.parse
import json
import base64
import io
from urllib.request import Request, urlopen

body = json.dumps({'camera': {'image_base64': 'base64str'}}).encode('utf-8')

try:
    req = Request('https://myna-ce-dev.glassdata.ai/inp', data=body, headers={'Content-Type': 'application/json'})
    res = urlopen(req)
    print("STATUS", res.getcode())
    print("BODY", res.read().decode())
except urllib.error.HTTPError as e:
    print("STATUS", e.code)
    print("BODY", e.read().decode())

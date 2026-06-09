import urllib.request
import urllib.parse
import json
import base64
import io
from urllib.request import Request, urlopen

boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
body = b'--' + boundary.encode() + b'\r\nContent-Disposition: form-data; name="file"; filename="frame.jpg"\r\nContent-Type: image/jpeg\r\n\r\n' + b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xd2\x8f\xff\xd9' + b'\r\n--' + boundary.encode() + b'\r\nContent-Disposition: form-data; name="gps_hazard"\r\n\r\nfalse\r\n--' + boundary.encode() + b'--\r\n'

try:
    req = Request('https://myna-ce-dev.glassdata.ai/inp', data=body, headers={'Content-Type': 'multipart/form-data; boundary=' + boundary})
    res = urlopen(req)
    print("STATUS", res.getcode())
    print("BODY", res.read().decode())
except urllib.error.HTTPError as e:
    print("STATUS", e.code)
    print("BODY", e.read().decode())

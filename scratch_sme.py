import urllib.request
import urllib.error

r = urllib.request.Request('https://myna-sme-dev.glassdata.ai/inp')
try:
    res = urllib.request.urlopen(r)
    print("STATUS", res.getcode())
except urllib.error.HTTPError as e:
    print("STATUS", e.code)
    print("BODY", e.read().decode())

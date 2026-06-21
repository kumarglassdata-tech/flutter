import asyncio
import websockets

async def test():
    try:
        async with websockets.connect('wss://myna-ie-dev.glassdata.ai/ws') as ws:
            print('Connected!')
    except Exception as e:
        print('Error:', e)

asyncio.run(test())

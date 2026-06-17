import asyncio
import websockets
import sys

async def test_connection():
    uri = 'wss://myna-ie-dev.glassdata.ai/ws'
    print(f'Attempting to connect to {uri}...')
    try:
        async with websockets.connect(uri) as websocket:
            print('Successfully connected to the WebSocket server!')
            return 0
    except Exception as e:
        print(f'Failed to connect: {e}')
        return 1

if __name__ == '__main__':
    sys.exit(asyncio.run(test_connection()))

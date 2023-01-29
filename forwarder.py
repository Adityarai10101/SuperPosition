import asyncio
import websockets

async def forward_data(websocket1, websocket2):
    while True:
        data = await websocket1.recv()
        await websocket2.send(data)

async def handle_client(websocket, path):
    # Get the other client's websocket
    other_client = clients[1] if clients[0] == websocket else clients[0]

    # Start forwarding data between the clients
    await asyncio.gather(forward_data(websocket, other_client), forward_data(other_client, websocket))

clients = []
start_server = websockets.serve(handle_client, "localhost", 8765)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()

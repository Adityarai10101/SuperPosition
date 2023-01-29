import asyncio
import websockets

async def get():
    async with websockets.connect("wss://superposition.herokuapp.com") as socket:
        while True:
            print(await socket.recv())

asyncio.get_event_loop().run_until_complete(get())
asyncio.get_event_loop().run_forever()
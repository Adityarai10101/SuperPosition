import asyncio
import websockets
import time
n = 0
async def send(theSocket):
    await theSocket.send(str(n))
    n += 1
    print(n)
async def message():

    async with websockets.connect("wss://superposition.herokuapp.com") as socket:
        while True:
            # msg = input("what to send?")
            send(socket)
            print('sent')
            time.sleep(1)

asyncio.get_event_loop().run_until_complete(message())
asyncio.get_event_loop().run_forever()
#!/usr/bin/env python3
"""Loopback fixture server for UI/network QA. Never runs alongside real Collector."""
import asyncio
import json
import os
from websockets.asyncio.server import serve

async def handle(ws):
    assert ws.request.path == '/socket.io/?EIO=4&transport=websocket'
    await ws.send('0' + json.dumps({'sid': 'local-test', 'upgrades': [], 'pingInterval': 1000, 'pingTimeout': 2000}))
    assert await ws.recv() == '40'
    await ws.send('40{"sid":"local-test"}')
    frames = [
        ['Connected', {'version': '0.2.52'}],
        ['OnSetBattleLineup', {'avatars': [{'id': 1310, 'name': 'Firefly'}, {'id': 1409, 'name': 'Hyacine'}]}],
        ['OnBattleBegin', {}],
        ['OnDamage', {'attacker': {'uid': 1310, 'team': 'Player'}, 'damage': 367648.1990259297}],
        ['OnDamage', {'attacker': {'uid': 1409, 'team': 'Player'}, 'damage': 12345.25}],
        ['OnDamage', {'attacker': {'uid': 1310, 'team': 'Player'}, 'damage': 100000.125}],
        ['OnBattleEnd', {'total_damage': 479993.5740259297}],
    ]
    try:
        for event in frames:
            await ws.send('42' + json.dumps(event))
            await asyncio.sleep(0.15)
        while True:
            await ws.send('2')
            assert await asyncio.wait_for(ws.recv(), timeout=2) == '3'
            await asyncio.sleep(1)
    except Exception:
        pass

async def main():
    port = int(os.environ.get('HSR_MOCK_PORT', '1305'))
    async with serve(handle, '127.0.0.1', port):
        print(f'LOCAL MOCK ONLY — 127.0.0.1:{port}', flush=True)
        await asyncio.Future()

if __name__ == '__main__':
    asyncio.run(main())

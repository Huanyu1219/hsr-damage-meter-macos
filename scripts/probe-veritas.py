#!/usr/bin/env python3
"""Read existing Veritas Socket.IO events over loopback; never controls the game."""
import argparse
from collections import Counter
import json
from pathlib import Path
import socket
import time
import urllib.error
import urllib.parse
import urllib.request


def probe(seconds: float) -> dict:
    base = 'http://127.0.0.1:1305/socket.io/?EIO=4&transport=polling'
    # Local transport must not be routed through an environment-configured proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    url = None
    counts = Counter()
    version = None
    first_damage = None

    def send(frame):
        request = urllib.request.Request(
            url, data=frame.encode(), headers={'Content-Type': 'text/plain'}
        )
        with opener.open(request, timeout=2) as response:
            response.read(100000)

    try:
        with opener.open(base, timeout=3) as response:
            frame = response.read(100000).decode()
        if not frame.startswith('0'):
            raise ValueError('Expected an Engine.IO v4 handshake')
        handshake = json.loads(frame[1:])
        url = base + '&sid=' + urllib.parse.quote(handshake['sid'])
        send('40')  # Join the default Socket.IO namespace, no gameplay command.
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline and sum(counts.values()) < 1000:
            try:
                with opener.open(url, timeout=max(0.1, min(3, deadline - time.monotonic()))) as response:
                    frames = response.read(100000).decode().split('\x1e')
            except (TimeoutError, socket.timeout):
                break
            for frame in frames:
                if frame == '2':
                    send('3')  # Engine.IO heartbeat.
                elif frame.startswith('42'):
                    event = json.loads(frame[2:])
                    if not isinstance(event, list) or len(event) != 2:
                        raise ValueError('Unexpected Socket.IO event shape')
                    name, payload = event
                    counts[name] += 1
                    if name == 'Connected':
                        version = payload.get('version')
                    elif name == 'OnDamage' and first_damage is None:
                        first_damage = payload
        if version is None:
            raise ValueError('No Veritas Connected event received')
        return {'collectorVersion': version, 'eventCounts': dict(counts),
                'firstDamage': first_damage,
                'note': 'Partial observation only; no replay, full-session totals or timing guarantee.'}
    finally:
        if url:
            try:
                send('1')  # Close our Engine.IO session, not the game/Collector.
            except (OSError, urllib.error.URLError):
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=10)
    parser.add_argument('--output', type=Path, help='Optional local JSON observation file')
    args = parser.parse_args()
    if not 0 < args.seconds <= 60:
        parser.error('--seconds must be greater than 0 and no more than 60')
    try:
        result = probe(args.seconds)
    except (OSError, urllib.error.URLError, ValueError, KeyError) as error:
        parser.exit(1, f'Veritas probe failed: {error}\n')
    text = json.dumps(result, ensure_ascii=False, indent=2)
    print(text)
    if args.output:
        args.output.write_text(text + '\n')


if __name__ == '__main__':
    main()

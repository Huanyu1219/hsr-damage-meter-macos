#!/usr/bin/env python3
"""Install a locally verified Collector variant while the game is stopped, with rollback."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ORIGINAL = 'd0bd2287b7b30f962a7a208c090bbe0ba2cff06e16dbc16ec1071821ea7667b2'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stopped():
    processes = subprocess.check_output(['ps', '-axo', 'comm='], text=True)
    if any(line.strip().lower().endswith('starrail.exe') for line in processes.splitlines()):
        raise SystemExit('Game is running. Exit StarRail before switching DLL variants.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('variant', choices=['no-ui', 'no-ui-info', 'control', 'original'])
    parser.add_argument(
        '--game-dir', type=Path,
        default=Path(os.environ['HSR_GAME_DIR']) if 'HSR_GAME_DIR' in os.environ else None,
        help='Game directory containing xluau.dll (or set HSR_GAME_DIR).',
    )
    args = parser.parse_args()
    if args.game_dir is None:
        parser.error('--game-dir or HSR_GAME_DIR is required')
    game = args.game_dir.expanduser().resolve()
    if not game.is_dir():
        parser.error(f'game directory does not exist: {game}')
    stopped()
    manifest = json.loads((ROOT / 'dist/collector-manifest.json').read_text())
    destination = game / 'xluau.dll'
    if not destination.is_file():
        raise SystemExit(f'xluau.dll not found in game directory: {game}')
    current = digest(destination)
    allowed = {ORIGINAL} | {v['sha256'] for v in manifest['variants'].values()}
    if current not in allowed:
        raise SystemExit('Current DLL differs from verified originals/builds; refusing to overwrite it.')
    backups = ROOT / 'backups/collector'
    backups.mkdir(parents=True, exist_ok=True)
    backup = backups / (current + '.dll')
    if not backup.exists():
        shutil.copy2(destination, backup)
    if digest(backup) != current:
        raise SystemExit('Backup hash verification failed.')
    if args.variant == 'original':
        source, expected = backups / (ORIGINAL + '.dll'), ORIGINAL
    else:
        variant = manifest['variants'][args.variant]
        source, expected = ROOT / variant['path'], variant['sha256']
    if digest(source) != expected:
        raise SystemExit('Candidate DLL hash verification failed.')
    stopped()
    fd, temp = tempfile.mkstemp(prefix='.xluau-staged-', suffix='.dll', dir=game)
    os.close(fd)
    try:
        shutil.copy2(source, temp)
        if digest(Path(temp)) != expected:
            raise SystemExit('Staged DLL hash verification failed.')
        stopped()
        os.replace(temp, destination)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    print(json.dumps({'installed': args.variant, 'sha256': digest(destination), 'backup': str(backup)}, ensure_ascii=False))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Verify generated ivory R1 image resources before an iOS release gate.

For a checked-out VeilLink repository:
  python3 VEILOPOLY_DEV/tools/verify_ivory_r1_assets.py --repo .
For an independent received asset handoff:
  python3 verify_ivory_r1_assets.py --manifest IVORY_R1_ASSET_LOCK.json --assets-dir Assets

Zero runtime dependencies, zero writes. No claims about iOS/SwiftUI rendering.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

RESOURCE_DIR = Path('VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources')
MANIFEST = Path('VEILOPOLY_DEV/INCOMING_ASSETS/IVORY_R1_20261107/IVORY_R1_ASSET_LOCK.json')
EXPECTED_ACTIVE = {'ivoryR1ChanceCard', 'ivoryR1ChestCard', 'ivoryR1VictoryBadge'}


def git_blob_sha1(raw: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\x00' + raw).hexdigest()


def png_dimensions(raw: bytes) -> tuple[int, int]:
    if len(raw) < 24 or raw[:8] != b'\x89PNG\r\n\x1a\n' or raw[12:16] != b'IHDR':
        raise ValueError('Missing PNG signature or IHDR')
    return struct.unpack('>II', raw[16:24])


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--assets-dir', type=Path)
    args = parser.parse_args()
    root = args.repo.resolve()
    metadata = args.manifest or (root / MANIFEST)
    images = args.assets_dir or (root / RESOURCE_DIR)
    lock = json.loads(metadata.read_text(encoding='utf-8'))
    entries = lock['pixel_assets']
    if len(entries) != 19:
        raise ValueError('Expected exactly 19 vetted assets')
    aliases = [x['alias'] for x in entries]
    ids = [x['id'] for x in entries]
    if len(set(aliases)) != 19 or len(set(ids)) != 19:
        raise ValueError('Duplicate resource alias or stable ID')
    active = {x['alias'] for x in entries if x['activation'] == 'activate'}
    if active != EXPECTED_ACTIVE:
        raise ValueError('Runtime activation boundary changed: ' + str(active))
    total = 0
    for i, asset in enumerate(entries, 1):
        if asset['id'] != f'VL-IVORY-R1-{i:03d}':
            raise ValueError('Unexpected ID ordering')
        alias = asset['alias']
        if not alias.startswith('ivoryR1'):
            raise ValueError('Unexpected alias prefix: ' + alias)
        raw = (images / (alias + '.png')).read_bytes()
        if len(raw) != asset['bytes']:
            raise ValueError('Byte length differs for ' + alias)
        if hashlib.sha256(raw).hexdigest() != asset['generated_sha256']:
            raise ValueError('SHA256 mismatch for ' + alias)
        if git_blob_sha1(raw) != asset['git_blob_sha1']:
            raise ValueError('Git blob ID mismatch for ' + alias)
        if list(png_dimensions(raw)) != asset['dimensions']:
            raise ValueError('PNG dimensions mismatch for ' + alias)
        if not asset['target'].endswith('/Resources/' + alias + '.png'):
            raise ValueError('Resource target mismatch for ' + alias)
        total += len(raw)
    if total != 2293866:
        raise ValueError('Unexpected total asset size')
    print(json.dumps({'status': 'PASS', 'assets': 19, 'bytes': total,
                      'runtime_candidates_active': len(active),
                      'sha256_git_blob_dimensions': '19/19'}, ensure_ascii=False))


if __name__ == '__main__':
    run()
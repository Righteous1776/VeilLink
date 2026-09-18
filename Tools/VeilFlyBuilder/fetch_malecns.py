#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, urllib.request
from pathlib import Path

FLYAI_RELEASE = "https://github.com/alextitonis/fly.ai/releases/download/brain-v1"
PREBUILT = {
    "brain.npz": "cc9bd1ecd00bd703a6fa648bc6ad145c93c7c1ee53debdcc9ce0d1f4305e6aca",
    "weights.npz": "c29919aa44069a271b1ee978abe05fa9bf6e45e4ba3e436e92b624ef1b5be40c",
}
OFFICIAL_BUCKET = "https://storage.googleapis.com/flyem-male-cns/v1.0/connectome-data/flat-connectome"
OFFICIAL = [
    "body-annotations-male-cns-v1.0-minconf-0.5.feather",
    "body-neurotransmitters-male-cns-v1.0.feather",
    "connectome-weights-male-cns-v1.0-minconf-0.5.feather",
]

def sha(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    return h.hexdigest()

def download(url: str, dest: Path):
    dest.parent.mkdir(parents=True, exist_ok=True)
    part=dest.with_suffix(dest.suffix+'.part')
    req=urllib.request.Request(url, headers={'User-Agent':'VeilFlyBuilder/1'})
    with urllib.request.urlopen(req) as r, part.open('wb') as out:
        while True:
            chunk=r.read(1<<20)
            if not chunk: break
            out.write(chunk)
    part.replace(dest)

ap=argparse.ArgumentParser(description='Fetch pinned MaleCNS-derived or authoritative source data')
ap.add_argument('--dest', type=Path, required=True)
ap.add_argument('--mode', choices=['prebuilt','raw'], default='prebuilt')
args=ap.parse_args()
if args.mode=='prebuilt':
    for name, expected in PREBUILT.items():
        path=args.dest/name
        if not path.exists(): download(f'{FLYAI_RELEASE}/{name}', path)
        actual=sha(path)
        if actual!=expected: raise SystemExit(f'{name} sha256 mismatch: {actual}')
    print(json.dumps({'mode':'prebuilt','dataset':'male-cns:v1.0','files':PREBUILT}, indent=2))
else:
    for name in OFFICIAL:
        path=args.dest/name
        if not path.exists(): download(f'{OFFICIAL_BUCKET}/{name}', path)
    print(json.dumps({'mode':'raw','dataset':'male-cns:v1.0','files':{n:sha(args.dest/n) for n in OFFICIAL}}, indent=2))

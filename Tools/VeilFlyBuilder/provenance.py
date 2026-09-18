#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, platform, sys
from pathlib import Path

def sha(path: Path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    return h.hexdigest()

ap=argparse.ArgumentParser()
ap.add_argument('--output', type=Path, required=True)
ap.add_argument('--artifact', type=Path, action='append', default=[])
ap.add_argument('--command', action='append', default=[])
args=ap.parse_args()
obj={
  'schema':'VeilFlyProvenance/1',
  'dataset':'MaleCNS v1.0',
  'dataset_id':'male-cns:v1.0',
  'dataset_license':'CC BY 4.0',
  'authoritative_site':'https://male-cns.janelia.org/',
  'primary_reference':'https://github.com/alextitonis/fly.ai',
  'primary_reference_revision':'1dc982f62da58a29f920fdd4d645fcab4da23624',
  'primary_reference_license':'MIT',
  'commands':args.command,
  'artifacts':[{ 'path':str(p), 'sha256':sha(p), 'byte_count':p.stat().st_size } for p in args.artifact],
  'python':sys.version.split()[0], 'platform':platform.platform(),
}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(obj,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
print(args.output)

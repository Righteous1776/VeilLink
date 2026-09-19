#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, struct, sys

MAGIC=b"VFLY1\0\0\0"
HEADER=struct.Struct("<8sIIIIIIIIQQQQQQQQ32s")
HEADER_SIZE=HEADER.size

def sha(path: pathlib.Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1<<20), b''): h.update(c)
    return h.hexdigest()

def inspect(path: pathlib.Path, expected_tier: str) -> dict:
    raw=path.read_bytes()
    if len(raw) < HEADER_SIZE: raise ValueError(f"{path}: truncated")
    vals=HEADER.unpack_from(raw,0)
    (magic,version,header_size,endian,weight_encoding,neurons,edges,groups,members,
     offsets_pos,targets_pos,weights_pos,group_offsets_pos,group_neurons_pos,
     metadata_pos,metadata_len,payload_len,payload_hash)=vals
    if magic!=MAGIC or version!=1 or header_size!=HEADER_SIZE or endian!=0x01020304 or weight_encoding!=1:
        raise ValueError(f"{path}: unsupported VFLY1 header")
    if len(raw) != HEADER_SIZE + payload_len: raise ValueError(f"{path}: payload length mismatch")
    if hashlib.sha256(raw[HEADER_SIZE:]).digest()!=payload_hash: raise ValueError(f"{path}: payload sha256 mismatch")
    end=metadata_pos+metadata_len
    if metadata_pos < HEADER_SIZE or end > len(raw): raise ValueError(f"{path}: metadata out of bounds")
    metadata=json.loads(raw[metadata_pos:end].decode('utf-8'))
    if metadata.get('format')!='VFLY1': raise ValueError(f"{path}: wrong format")
    if metadata.get('dataset_id')!='male-cns:v1.0': raise ValueError(f"{path}: wrong dataset")
    if metadata.get('tier')!=expected_tier: raise ValueError(f"{path}: tier {metadata.get('tier')} != {expected_tier}")
    return {
        'filename': path.name,
        'tier': expected_tier,
        'sha256': sha(path),
        'byte_count': len(raw),
        'neuron_count': neurons,
        'edge_count': edges,
        'group_count': groups,
        'group_member_count': members,
        'graph_id': metadata.get('graph_id'),
        'dataset_id': metadata.get('dataset_id'),
        'parent_graph_sha256': metadata.get('parent_graph_sha256'),
    }

def main() -> int:
    ap=argparse.ArgumentParser(description='Verify installed VeilFly Core/Lite assets without NumPy')
    ap.add_argument('resource_dir', type=pathlib.Path, nargs='?', default=pathlib.Path('VeilLink/Resources'))
    ap.add_argument('--json-out', type=pathlib.Path)
    args=ap.parse_args()
    d=args.resource_dir
    core=d/'VeilFlyCore.vfly'; lite=d/'VeilFlyLite.vfly'; manifest_path=d/'VeilFlyAssets.json'
    if not core.is_file() or not lite.is_file(): raise SystemExit('missing VeilFlyCore.vfly or VeilFlyLite.vfly')
    if (d/'MaleCNSReference.vfly').exists(): raise SystemExit('full MaleCNSReference.vfly must never ship in app resources')
    if not manifest_path.is_file(): raise SystemExit('missing VeilFlyAssets.json')
    assets=[inspect(core,'core'), inspect(lite,'lite')]
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    if manifest.get('schema')!='VeilFlyBundleAssets/1' or manifest.get('dataset_id')!='male-cns:v1.0':
        raise SystemExit('invalid VeilFlyAssets.json')
    listed={x.get('filename'):x for x in manifest.get('assets',[])}
    for item in assets:
        m=listed.get(item['filename'])
        if not m: raise SystemExit(f"manifest missing {item['filename']}")
        if m.get('sha256')!=item['sha256'] or int(m.get('byte_count',-1))!=item['byte_count']:
            raise SystemExit(f"manifest mismatch for {item['filename']}")
        if m.get('tier')!=item['tier'] or m.get('dataset_id')!='male-cns:v1.0':
            raise SystemExit(f"manifest metadata mismatch for {item['filename']}")
    report={'schema':'VeilFlyInstalledVerification/1','result':'PASS','dataset_id':'male-cns:v1.0','assets':assets}
    payload=json.dumps(report,ensure_ascii=False,indent=2,sort_keys=True)+'\n'
    if args.json_out:
        args.json_out.parent.mkdir(parents=True,exist_ok=True); args.json_out.write_text(payload,encoding='utf-8')
    print(payload,end='')
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as e:
        print(f'ERROR: {e}',file=sys.stderr); raise

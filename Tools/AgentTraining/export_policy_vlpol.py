#!/usr/bin/env python3
import argparse, hashlib, json, struct
from pathlib import Path
import torch

ORDER = [
    'game.weight',
    'state.0.weight','state.0.bias','state.2.weight','state.2.bias','state.3.weight','state.3.bias',
    'action.0.weight','action.0.bias','action.2.weight','action.2.bias','action.3.weight','action.3.bias',
    'head.0.weight','head.0.bias','head.3.weight','head.3.bias','head.5.weight','head.5.bias',
]
MAGIC=b'VLPOL1'

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--checkpoint',required=True)
    ap.add_argument('--out',required=True)
    ap.add_argument('--manifest',required=True)
    args=ap.parse_args()
    ckpt=Path(args.checkpoint); out=Path(args.out); man=Path(args.manifest)
    payload=torch.load(ckpt,map_location='cpu',weights_only=False)
    sd=payload['state_dict']
    missing=[k for k in ORDER if k not in sd]
    if missing: raise SystemExit(f'missing tensors: {missing}')
    out.parent.mkdir(parents=True,exist_ok=True); man.parent.mkdir(parents=True,exist_ok=True)
    with out.open('wb') as f:
        f.write(MAGIC)
        f.write(struct.pack('<II',1,len(ORDER)))
        for name in ORDER:
            t=sd[name].detach().to(torch.float32).contiguous().cpu()
            rawname=name.encode('utf-8')
            f.write(struct.pack('<H',len(rawname))); f.write(rawname)
            f.write(struct.pack('<B',t.ndim))
            for d in t.shape: f.write(struct.pack('<I',int(d)))
            flat=t.reshape(-1).numpy().astype('<f4',copy=False).tobytes()
            f.write(struct.pack('<I',t.numel())); f.write(flat)
    blob=out.read_bytes(); source=ckpt.read_bytes()
    manifest={
      'id':'veillink.game-policy.ranker.v4', 'format':'VLPOL1', 'format_version':1,
      'games':['gomoku','xiangqi','ludo'], 'excluded_games':['tactical'],
      'state_dim':256,'action_dim':16,'source_checkpoint_sha256':hashlib.sha256(source).hexdigest(),
      'sha256':hashlib.sha256(blob).hexdigest(),'byte_count':len(blob),
      'inference':'float32 Linear/GELU/LayerNorm; Dropout disabled at inference',
      'training_metric_note':'agreement with heuristic self-play teacher, not expert strength or MaleCNS'
    }
    man.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False))
if __name__=='__main__': main()

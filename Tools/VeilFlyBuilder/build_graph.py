#!/usr/bin/env python3
"""Rebuild fly.ai-compatible brain.npz/weights.npz from authoritative MaleCNS v1.0 tables.

This is intentionally build-host tooling. It follows the pinned fly.ai recipe:
- retain neurons with non-empty superclass annotation;
- sign outgoing weights by predicted transmitter (GABA/glutamate/histamine inhibitory);
- normalize each postsynaptic neuron's incoming absolute weight sum to 1;
- output W with rows=post, cols=pre, plus compact metadata/readout groups.

The optic-column eye mapping is optional here because VeilLink's first VFLY runtime injects known
feature-detector groups directly. A later visual-encoder phase can add optic columns without
changing VFLY graph semantics.
"""
from __future__ import annotations

import argparse, json, re
from pathlib import Path
import numpy as np
from scipy import sparse

INHIBITORY = "gaba|glutamate|histamine"
MOTOR_TYPES = {
    "forward": ["DNg100"],
    "steer": ["DNa02"],
    "escape": ["DNp01"],
    "backward": ["MDN"],
    "punch": ["DNg11"],
    "kick": ["pIP10"],
}

def main() -> None:
    try:
        import pyarrow.feather as feather
    except ImportError as exc:
        raise SystemExit('pyarrow is required: pip install -r Tools/VeilFlyBuilder/requirements.txt') from exc

    ap=argparse.ArgumentParser()
    ap.add_argument('--raw', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args=ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ann_path=args.raw/'body-annotations-male-cns-v1.0-minconf-0.5.feather'
    nt_path=args.raw/'body-neurotransmitters-male-cns-v1.0.feather'
    edge_path=args.raw/'connectome-weights-male-cns-v1.0-minconf-0.5.feather'
    for p in (ann_path,nt_path,edge_path):
        if not p.exists(): raise SystemExit(f'missing {p}')

    ann=feather.read_table(ann_path).to_pandas()
    nt=feather.read_table(nt_path, columns=['body','consensus_nt']).to_pandas()
    ann=ann.loc[ann['superclass'].notna() & ann['superclass'].ne('')]
    ann=ann.drop_duplicates('bodyId').sort_values('bodyId').set_index('bodyId')
    ids=ann.index.to_numpy(np.int64); n=len(ids)
    labels=nt.drop_duplicates('body').set_index('body').reindex(ids)['consensus_nt']
    sign=np.where(labels.fillna('unclear').str.lower().str.contains(INHIBITORY),-1.0,1.0).astype(np.float32)

    edges=feather.read_table(edge_path, columns=['body_pre','body_post','weight'], memory_map=True)
    pre_parts=[]; post_parts=[]; w_parts=[]
    for batch in edges.to_batches(max_chunksize=4_000_000):
        pre_id=batch.column(0).to_numpy(zero_copy_only=False)
        post_id=batch.column(1).to_numpy(zero_copy_only=False)
        pre=np.minimum(np.searchsorted(ids,pre_id),n-1)
        post=np.minimum(np.searchsorted(ids,post_id),n-1)
        ok=(ids[pre]==pre_id)&(ids[post]==post_id)
        pre_parts.append(pre[ok].astype(np.int32)); post_parts.append(post[ok].astype(np.int32))
        w_parts.append(batch.column(2).to_numpy(zero_copy_only=False)[ok].astype(np.float32))
    pre,post,w=(np.concatenate(x) for x in (pre_parts,post_parts,w_parts))
    w*=sign[pre]
    incoming=np.bincount(post,weights=np.abs(w),minlength=n).astype(np.float32)
    w/=np.maximum(incoming[post],1.0)
    W=sparse.csr_matrix((w,(post,pre)),shape=(n,n),dtype=np.float32)

    cell_type=ann['flywireType'].fillna(ann['type']).fillna('').astype(str)
    side=ann['somaSide'].fillna(ann['rootSide']).fillna('').astype(str).str.upper()
    instance=ann['instance'].fillna('').astype(str).str.upper()
    def pick(types,want_side=None):
        mask=cell_type.isin(types)
        if want_side: mask &= (side==want_side)|instance.str.contains(f'_{want_side}')
        return np.flatnonzero(mask.to_numpy()).astype(np.int32)
    groups={}
    for name,types in MOTOR_TYPES.items():
        groups[f'{name}_L']=pick(types,'L'); groups[f'{name}_R']=pick(types,'R')
    visual=pick(['R1-6','R7','R8'])
    positions=np.full((n,3),np.nan,np.float32)
    if 'somaLocation' in ann.columns and 'tosomaLocation' in ann.columns:
        for i,(soma,to_soma) in enumerate(zip(ann['somaLocation'],ann['tosomaLocation'])):
            loc=soma if isinstance(soma,(list,np.ndarray)) and len(soma)==3 else to_soma
            if isinstance(loc,(list,np.ndarray)) and len(loc)==3: positions[i]=loc
    sparse.save_npz(args.output/'weights.npz',W,compressed=False)
    np.savez(args.output/'brain.npz', ids=ids, visual=visual, azimuth=np.zeros(len(visual),np.float32),
             cell_type=cell_type.to_numpy().astype(str), side=side.to_numpy().astype(str), positions=positions,
             superclass=ann['superclass'].to_numpy().astype(str), **{f'group_{k}':v for k,v in groups.items()})
    summary={'neurons':n,'connections':int(W.nnz),'photoreceptors':int(len(visual)),'groups':{k:int(len(v)) for k,v in groups.items()}}
    (args.output/'brain.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
    print(json.dumps(summary,indent=2,sort_keys=True))

if __name__=='__main__': main()

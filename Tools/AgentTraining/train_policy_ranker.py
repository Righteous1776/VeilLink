#!/usr/bin/env python3
import argparse, collections, hashlib, json, math, os, random, time
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

GAME_IDS={'gomoku':0,'xiangqi':1,'ludo':2}

class Decision:
    __slots__=('game','state','actions','target')
    def __init__(self, game, state, actions, target):
        self.game=game; self.state=state; self.actions=actions; self.target=target

class DecisionDataset(Dataset):
    def __init__(self,path):
        groups=collections.OrderedDict()
        with open(path,'r',encoding='utf-8') as f:
            for line in f:
                if not line.strip(): continue
                r=json.loads(line)
                if r['game'] not in GAME_IDS: continue
                key=(r['game'],int(r['episode']),int(r['ply']))
                g=groups.setdefault(key, {'game':r['game'],'state':r['state'],'actions':[],'target':None})
                g['actions'].append(r['action'])
                if float(r['label'])>0.5: g['target']=len(g['actions'])-1
        self.items=[]
        for g in groups.values():
            if g['target'] is None or len(g['actions'])<1: continue
            self.items.append(Decision(g['game'],g['state'],g['actions'],g['target']))
    def __len__(self): return len(self.items)
    def __getitem__(self,i): return self.items[i]

def collate(batch):
    # Encode each decision state once, flatten only variable candidate actions, and retain a
    # candidate->decision index. This avoids recomputing the 256-d state encoder per candidate.
    states=[]; actions=[]; games=[]; candidate_to_decision=[]; offsets=[0]; targets=[]
    for decision_index,d in enumerate(batch):
        n=len(d.actions)
        states.append(d.state); actions.extend(d.actions); games.append(GAME_IDS[d.game])
        candidate_to_decision.extend([decision_index]*n)
        targets.append(offsets[-1]+d.target); offsets.append(offsets[-1]+n)
    return (torch.tensor(states,dtype=torch.float32), torch.tensor(actions,dtype=torch.float32),
            torch.tensor(games,dtype=torch.long), torch.tensor(candidate_to_decision,dtype=torch.long),
            torch.tensor(offsets,dtype=torch.long),
            torch.tensor(targets,dtype=torch.long))

class CandidateRanker(nn.Module):
    def __init__(self):
        super().__init__()
        self.game=nn.Embedding(3,24)
        self.state=nn.Sequential(nn.Linear(256,320),nn.GELU(),nn.LayerNorm(320),nn.Linear(320,192),nn.GELU())
        self.action=nn.Sequential(nn.Linear(16,96),nn.GELU(),nn.LayerNorm(96),nn.Linear(96,80),nn.GELU())
        self.head=nn.Sequential(nn.Linear(192+80+24,160),nn.GELU(),nn.Dropout(0.06),nn.Linear(160,64),nn.GELU(),nn.Linear(64,1))
    def forward(self,s,a,g,candidate_to_decision):
        state_features=self.state(s)
        game_features=self.game(g)
        action_features=self.action(a)
        return self.head(torch.cat([
            state_features[candidate_to_decision],
            action_features,
            game_features[candidate_to_decision]
        ],dim=-1)).squeeze(-1)

def padded_scores(scores, offsets, targets):
    """Pack flattened variable-length candidate scores into one padded batch matrix."""
    starts=offsets[:-1]
    lengths=offsets[1:]-starts
    rows=len(lengths)
    max_len=int(lengths.max().item())
    padded=scores.new_full((rows,max_len),float('-inf'))
    row_ids=torch.repeat_interleave(torch.arange(rows,device=scores.device),lengths)
    flat_positions=torch.arange(scores.numel(),device=scores.device)
    col_ids=flat_positions-torch.repeat_interleave(starts,lengths)
    padded[row_ids,col_ids]=scores
    relative_targets=targets-starts
    return padded,relative_targets

def listwise_loss(scores, offsets, targets):
    padded,target=padded_scores(scores,offsets,targets)
    return nn.functional.cross_entropy(padded,target)

def decision_ranks(scores, offsets, targets):
    padded,target=padded_scores(scores,offsets,targets)
    target_scores=padded.gather(1,target[:,None]).squeeze(1)
    return 1+(padded>target_scores[:,None]).sum(dim=1)

def metrics(scores, offsets, targets):
    ranks=decision_ranks(scores,offsets,targets)
    top1=(ranks==1).sum().item()
    rr=(1.0/ranks.float()).sum().item()
    return top1,rr,len(targets)

def split_indices(ds, seed, val_fraction=.1):
    """Stratify by game so small games cannot disappear into a Ludo-heavy validation split."""
    rng=random.Random(seed); train=[]; val=[]
    bygame=collections.defaultdict(list)
    for i,item in enumerate(ds.items): bygame[item.game].append(i)
    for game in GAME_IDS:
        ids=bygame[game]; rng.shuffle(ids)
        nval=max(1,int(len(ids)*val_fraction))
        val.extend(ids[:nval]); train.extend(ids[nval:])
    rng.shuffle(train); rng.shuffle(val)
    return train,val

class Subset(Dataset):
    def __init__(self,base,ids): self.base=base; self.ids=ids
    def __len__(self): return len(self.ids)
    def __getitem__(self,i): return self.base[self.ids[i]]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--data',required=True); ap.add_argument('--out',required=True)
    ap.add_argument('--epochs',type=int,default=8); ap.add_argument('--batch-decisions',type=int,default=256)
    ap.add_argument('--lr',type=float,default=8e-4); ap.add_argument('--seed',type=int,default=1776); ap.add_argument('--workers',type=int,default=0)
    ap.add_argument('--unbalanced-games',action='store_true',help='disable inverse-frequency game balancing')
    ap.add_argument('--epoch-decisions',type=int,default=0,help='sample this many training decisions per epoch; 0 = full train split')
    args=ap.parse_args(); torch.manual_seed(args.seed); random.seed(args.seed)
    device=torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    ds=DecisionDataset(args.data); train_ids,val_ids=split_indices(ds,args.seed)
    train=Subset(ds,train_ids); val=Subset(ds,val_ids)
    if args.unbalanced_games:
        train_loader=DataLoader(train,batch_size=args.batch_decisions,shuffle=True,num_workers=args.workers,collate_fn=collate)
    else:
        counts=collections.Counter(train.base.items[i].game for i in train.ids)
        weights=[1.0/counts[train.base.items[i].game] for i in train.ids]
        generator=torch.Generator().manual_seed(args.seed)
        samples=len(train) if args.epoch_decisions <= 0 else min(args.epoch_decisions, len(train))
        sampler=WeightedRandomSampler(weights,num_samples=samples,replacement=True,generator=generator)
        train_loader=DataLoader(train,batch_size=args.batch_decisions,sampler=sampler,num_workers=args.workers,collate_fn=collate)
    val_loader=DataLoader(val,batch_size=args.batch_decisions,shuffle=False,num_workers=args.workers,collate_fn=collate)
    model=CandidateRanker().to(device); opt=torch.optim.AdamW(model.parameters(),lr=args.lr,weight_decay=1e-4)
    scaler=torch.amp.GradScaler('cuda',enabled=torch.cuda.is_available()); best=-1.; best_loss=1e9
    out=Path(args.out); out.parent.mkdir(parents=True,exist_ok=True); started=time.time()
    for epoch in range(1,args.epochs+1):
        model.train(); tr_loss=0.; tr_n=0
        for s,a,g,c2d,off,targ in train_loader:
            s,a,g,c2d=s.to(device),a.to(device),g.to(device),c2d.to(device); off,targ=off.to(device),targ.to(device)
            opt.zero_grad(set_to_none=True)
            with torch.autocast(device_type='cuda',dtype=torch.float16,enabled=torch.cuda.is_available()):
                score=model(s,a,g,c2d); loss=listwise_loss(score,off,targ)
            scaler.scale(loss).backward(); scaler.step(opt); scaler.update(); tr_loss+=loss.item()*(len(off)-1); tr_n+=len(off)-1
        model.eval(); vl=0.; vn=0; top=0; rr=0.
        pergame={k:[0,0.,0] for k in GAME_IDS}
        with torch.no_grad():
            for batch in val_loader:
                s,a,g,c2d,off,targ=batch; s,a,g,c2d=s.to(device),a.to(device),g.to(device),c2d.to(device); off,targ=off.to(device),targ.to(device)
                score=model(s,a,g,c2d); loss=listwise_loss(score,off,targ); vl+=loss.item()*(len(off)-1); vn+=len(off)-1
                ranks=decision_ranks(score,off,targ)
                top+=(ranks==1).sum().item(); rr+=(1.0/ranks.float()).sum().item()
                for name,gid in GAME_IDS.items():
                    mask=(g==gid)
                    if not mask.any(): continue
                    selected=ranks[mask]
                    pergame[name][0]+=(selected==1).sum().item()
                    pergame[name][1]+=(1.0/selected.float()).sum().item()
                    pergame[name][2]+=int(mask.sum().item())
        val_loss=vl/max(1,vn); top1=top/max(1,vn); mrr=rr/max(1,vn)
        epoch_pergame={k:{'top1':v[0]/max(1,v[2]),'mrr':v[1]/max(1,v[2]),'decisions':v[2]} for k,v in pergame.items()}
        macro_top1=sum(v['top1'] for v in epoch_pergame.values())/len(epoch_pergame)
        macro_mrr=sum(v['mrr'] for v in epoch_pergame.values())/len(epoch_pergame)
        print(f'epoch={epoch} train_loss={tr_loss/max(1,tr_n):.5f} val_loss={val_loss:.5f} top1={top1:.4f} macro_top1={macro_top1:.4f} mrr={mrr:.4f} macro_mrr={macro_mrr:.4f}',flush=True)
        if macro_top1>best or (math.isclose(macro_top1,best) and val_loss<best_loss):
            best=macro_top1; best_loss=val_loss
            torch.save({'state_dict':model.state_dict(),'schema':4,'games':list(GAME_IDS),'state_dim':256,'action_dim':16,'objective':'balanced-listwise-ranking'},out)
            best_pergame=epoch_pergame; best_overall={'top1':top1,'mrr':mrr,'macro_mrr':macro_mrr,'epoch':epoch}
    blob=out.read_bytes(); sha=hashlib.sha256(blob).hexdigest()
    manifest={'id':'veillink.game-policy.ranker.v4','schema':4,'games':list(GAME_IDS),'excluded_games':['tactical'],
              'training_decisions':len(train),'validation_decisions':len(val),'source_rows':sum(len(x.actions) for x in ds.items),
              'epochs':args.epochs,'best_macro_top1':best,'best_val_loss':best_loss,'best_overall_validation':best_overall,'per_game_validation':best_pergame,
              'game_balanced_sampling':not args.unbalanced_games,
              'epoch_decisions':len(train) if args.epoch_decisions <= 0 else min(args.epoch_decisions,len(train)),
              'device':str(device),'wall_seconds':round(time.time()-started,3),'sha256':sha,'byte_count':len(blob),
              'objective':'game-balanced listwise candidate ranking; macro Top-1 checkpoint selection; engine legality remains authoritative; tactical excluded; not MaleCNS'}
    out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False),flush=True)
if __name__=='__main__': main()

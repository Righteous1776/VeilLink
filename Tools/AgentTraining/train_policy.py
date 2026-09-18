#!/usr/bin/env python3
import argparse, hashlib, json, os, random, time
from pathlib import Path

import torch
import torch.distributed as dist
from torch import nn
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import Dataset, DataLoader, DistributedSampler, random_split

class Rows(Dataset):
    def __init__(self, path):
        self.rows=[]
        with open(path,'r',encoding='utf-8') as f:
            for line in f:
                if line.strip(): self.rows.append(json.loads(line))
        self.game_ids={"gomoku":0,"xiangqi":1,"ludo":2}
    def __len__(self): return len(self.rows)
    def __getitem__(self,i):
        r=self.rows[i]
        return (torch.tensor(r['state'],dtype=torch.float32),
                torch.tensor(r['action'],dtype=torch.float32),
                torch.tensor(self.game_ids[r['game']],dtype=torch.long),
                torch.tensor(r['label'],dtype=torch.float32))

class CandidateScorer(nn.Module):
    def __init__(self):
        super().__init__()
        self.game=nn.Embedding(3,16)
        self.state=nn.Sequential(nn.Linear(256,256),nn.GELU(),nn.LayerNorm(256),nn.Linear(256,160),nn.GELU())
        self.action=nn.Sequential(nn.Linear(16,80),nn.GELU(),nn.LayerNorm(80))
        self.head=nn.Sequential(nn.Linear(160+80+16,128),nn.GELU(),nn.Dropout(0.08),nn.Linear(128,1))
    def forward(self,s,a,g):
        return self.head(torch.cat([self.state(s),self.action(a),self.game(g)],dim=-1)).squeeze(-1)

def setup_distributed():
    world=int(os.environ.get('WORLD_SIZE','1'))
    rank=int(os.environ.get('RANK','0'))
    local_rank=int(os.environ.get('LOCAL_RANK','0'))
    if world>1:
        backend='nccl' if torch.cuda.is_available() else 'gloo'
        dist.init_process_group(backend=backend)
    return world,rank,local_rank

def reduce_sum(value, device, world):
    t=torch.tensor(float(value),device=device)
    if world>1: dist.all_reduce(t,op=dist.ReduceOp.SUM)
    return t.item()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--data',required=True); ap.add_argument('--out',required=True)
    ap.add_argument('--epochs',type=int,default=12); ap.add_argument('--batch-size',type=int,default=1024)
    ap.add_argument('--lr',type=float,default=1.5e-3); ap.add_argument('--seed',type=int,default=1776)
    ap.add_argument('--workers',type=int,default=0)
    args=ap.parse_args()
    world,rank,local_rank=setup_distributed()
    torch.manual_seed(args.seed+rank); random.seed(args.seed+rank)
    if torch.cuda.is_available():
        device=torch.device('cuda',local_rank); torch.cuda.set_device(device)
    else: device=torch.device('cpu')
    ds=Rows(args.data)
    n_val=max(1,int(len(ds)*0.1)); n_train=len(ds)-n_val
    train,val=random_split(ds,[n_train,n_val],generator=torch.Generator().manual_seed(args.seed))
    train_sampler=DistributedSampler(train,num_replicas=world,rank=rank,shuffle=True,seed=args.seed) if world>1 else None
    val_sampler=DistributedSampler(val,num_replicas=world,rank=rank,shuffle=False) if world>1 else None
    train_loader=DataLoader(train,batch_size=args.batch_size,shuffle=train_sampler is None,sampler=train_sampler,num_workers=args.workers,pin_memory=torch.cuda.is_available())
    val_loader=DataLoader(val,batch_size=args.batch_size,shuffle=False,sampler=val_sampler,num_workers=args.workers,pin_memory=torch.cuda.is_available())
    raw_model=CandidateScorer().to(device)
    model=DDP(raw_model,device_ids=[local_rank] if torch.cuda.is_available() else None) if world>1 else raw_model
    opt=torch.optim.AdamW(model.parameters(),lr=args.lr,weight_decay=1e-4)
    loss_fn=nn.BCEWithLogitsLoss()
    scaler=torch.amp.GradScaler('cuda',enabled=torch.cuda.is_available())
    best=1e9; out=Path(args.out); out.parent.mkdir(parents=True,exist_ok=True)
    started=time.time()
    for epoch in range(1,args.epochs+1):
        if train_sampler: train_sampler.set_epoch(epoch)
        model.train(); total=0.; count=0
        for s,a,g,y in train_loader:
            s,a,g,y=s.to(device,non_blocking=True),a.to(device,non_blocking=True),g.to(device,non_blocking=True),y.to(device,non_blocking=True)
            opt.zero_grad(set_to_none=True)
            with torch.autocast(device_type='cuda',dtype=torch.float16,enabled=torch.cuda.is_available()):
                logits=model(s,a,g); loss=loss_fn(logits,y)
            scaler.scale(loss).backward(); scaler.step(opt); scaler.update()
            total+=loss.item()*len(y); count+=len(y)
        model.eval(); vtotal=0.; vcount=0; correct=0
        with torch.no_grad():
            for s,a,g,y in val_loader:
                s,a,g,y=s.to(device,non_blocking=True),a.to(device,non_blocking=True),g.to(device,non_blocking=True),y.to(device,non_blocking=True)
                with torch.autocast(device_type='cuda',dtype=torch.float16,enabled=torch.cuda.is_available()):
                    logits=model(s,a,g); loss=loss_fn(logits,y)
                vtotal+=loss.item()*len(y); vcount+=len(y)
                correct+=((logits.sigmoid()>=0.5)==(y>=0.5)).sum().item()
        total=reduce_sum(total,device,world); count=reduce_sum(count,device,world)
        vtotal=reduce_sum(vtotal,device,world); vcount=reduce_sum(vcount,device,world); correct=reduce_sum(correct,device,world)
        tl=total/max(1,count); vl=vtotal/max(1,vcount); acc=correct/max(1,vcount)
        if rank==0:
            print(f"epoch={epoch} train_loss={tl:.5f} val_loss={vl:.5f} val_acc={acc:.4f} world={world}",flush=True)
            if vl<best:
                best=vl
                target=model.module if isinstance(model,DDP) else model
                torch.save({'state_dict':target.state_dict(),'schema':2,'games':['gomoku','xiangqi','ludo'],'state_dim':256,'action_dim':16},out)
        if world>1: dist.barrier()
    if rank==0:
        blob=out.read_bytes(); sha=hashlib.sha256(blob).hexdigest()
        manifest={
          'id':'veillink.game-policy.bootstrap.v2','schema':2,'games':['gomoku','xiangqi','ludo'],
          'excluded_games':['tactical'],'training_rows':len(ds),'epochs':args.epochs,'best_val_loss':best,
          'device':str(device),'world_size':world,'wall_seconds':round(time.time()-started,3),'sha256':sha,'byte_count':len(blob),
          'note':'bootstrap imitation candidate scorer; legal actions still validated by VeilLink game engines; not MaleCNS'
        }
        out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(manifest,ensure_ascii=False),flush=True)
    if world>1: dist.destroy_process_group()
if __name__=='__main__': main()

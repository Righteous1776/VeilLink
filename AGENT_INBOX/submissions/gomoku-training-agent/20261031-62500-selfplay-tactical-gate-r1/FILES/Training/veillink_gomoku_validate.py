import json,importlib.util,sys,time,hashlib
from pathlib import Path
p='/mnt/data/veillink_gomoku_selfplay_train.py'
spec=importlib.util.spec_from_file_location('vt',p)
vt=importlib.util.module_from_spec(spec);spec.loader.exec_module(vt)
raw=Path('/mnt/data/VeilLink-GomokuLearning-20261031-132217.vltrain.json').read_bytes()
# Training outcomes: captured from the deterministic earlier 50k run.
raw_train={"0":[2942,3058,4000,62.65],"50":[2898,3065,4037,63.91],"200":[2897,3214,3889,62.77],"800":[1818,3596,4586,66.66],"3200":[1501,4391,4108,63.69]}
train={k:{'win':x[0],'loss':x[1],'draw':x[2],'total':10000,'avg_turns':x[3]} for k,x in raw_train.items()}
val={}
_ = vt.play(0,0,12345,75.0)
for w in [0,50,200,800,3200]:
 t=time.perf_counter();win,loss,draw,turn=vt.tournament(w,2500,15000000+1103*w,75.0)
 val[str(w)]={'win':int(win),'loss':int(loss),'draw':int(draw),'total':2500,'avg_turns':round(float(turn)/2500,2)}
 print('eval',w,val[str(w)],round(time.perf_counter()-t,2),flush=True)

tac={'must_win':0,'must_block':0,'fail_win':0,'fail_block':0}
import numpy as np
for pattern in range(16):
 board=np.zeros(225,np.int8);occ=np.empty(225,np.int16)
 c=2+pattern%5;r=3+pattern%4
 if pattern%4==0:coords=[(r,c+k) for k in range(4)]
 elif pattern%4==1:coords=[(r+k,c) for k in range(4)]
 elif pattern%4==2:coords=[(r+k,c+k) for k in range(4)]
 else:coords=[(r+k,c+3-k) for k in range(4)]
 for k,(rr,cc) in enumerate(coords):board[rr*15+cc]=1;occ[k]=rr*15+cc
 for side in [1,2]:
  idx,_=vt.choose(board,occ,4,side,-1,3200,np.uint32(9999),0)
  if side==1:
   tac['must_win']+=1
   if idx<0 or not vt.winning_if(board,idx,1):tac['fail_win']+=1
  else:
   tac['must_block']+=1
   if idx<0 or not vt.winning_if(board,idx,1):tac['fail_block']+=1

report={'engine':'Offline Numba surrogate, freestyle 15x15, not VeilLink native Swift engine', 'source_export_sha256':hashlib.sha256(raw).hexdigest(),'real_records':28,'real_host_moves':700,'real_host_knight_transitions':196,'real_host_total_transitions':672,'trainer_seed_start':1000000,'validation_seed_start':15000000,'training_total_games':50000,'training_vs_unmodified_baseline':train,'validation_total_games':12500,'validation_vs_unmodified_baseline':val,'style_chosen':0,'selection':'Fail-closed: none of the positive style weights beats zero-style baseline on both training and independent evaluation; disable mandatory knight bonus','tactical_oracle':tac,'not_claimed':['Not the Swift GomokuBot or a Core ML network','Not measured against Rapfi/human experts','No iOS binaries or weights trained','Only synthetic surrogate self-play with 90-turn cap','No native promotion']}
out=Path('/mnt/data/VeilLink-Gomoku-SelfPlay-20261031-result.json');out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('WROTE',out,'bytes',out.stat().st_size,flush=True)

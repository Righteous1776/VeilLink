#!/usr/bin/env python3
"""VeilLink offline Gomoku style ablation. Freestyle 15x15, surrogate policy, not shipping app model.
Independent deterministic PRNG seeds; train/eval domains separated. Requires numpy, numba.
"""
import json,hashlib,statistics,collections,sys,time
from pathlib import Path
import numpy as np
from numba import njit

N=15
@njit(cache=True)
def xor_shift(x):
    x^=(x<<13)&0xffffffff
    x^=x>>17
    x^=(x<<5)&0xffffffff
    return x&0xffffffff

@njit(cache=True)
def line_win(board,pos,side):
    row=pos//15;col=pos%15
    for di in range(4):
        if di==0: dr,dc=1,0
        elif di==1:dr,dc=0,1
        elif di==2:dr,dc=1,1
        else:dr,dc=1,-1
        cnt=1
        for sign in (-1,1):
            r=row+sign*dr;c=col+sign*dc
            while 0<=r<15 and 0<=c<15 and board[r*15+c]==side:
                cnt+=1;r+=sign*dr;c+=sign*dc
        if cnt>=5:return True
    return False

@njit(cache=True)
def winning_if(board,pos,side):
    if board[pos]!=0:return False
    board[pos]=side
    ans=line_win(board,pos,side)
    board[pos]=0
    return ans

@njit(cache=True)
def placement(board,pos,side):
    row=pos//15; col=pos%15
    total=0
    for di in range(4):
        if di==0:dr,dc=1,0
        elif di==1:dr,dc=0,1
        elif di==2:dr,dc=1,1
        else:dr,dc=1,-1
        a=0;b=0
        r=row+dr;c=col+dc
        while 0<=r<15 and 0<=c<15 and board[r*15+c]==side:
            a+=1;r+=dr;c+=dc
        opena=0<=r<15 and 0<=c<15 and board[r*15+c]==0
        r=row-dr;c=col-dc
        while 0<=r<15 and 0<=c<15 and board[r*15+c]==side:
            b+=1;r-=dr;c-=dc
        openb=0<=r<15 and 0<=c<15 and board[r*15+c]==0
        run=a+b+1; op=int(opena)+int(openb)
        if run>=5:total+=120000
        elif run==4:total+=(22000 if op==2 else 8000 if op==1 else 0)
        elif run==3:total+=(2000 if op==2 else 500 if op==1 else 0)
        elif run==2:total+=(160 if op==2 else 45 if op==1 else 0)
        else:total+=op*5
    return total

@njit(cache=True)
def get_candidates(board,occupied,nocc):
    near=np.zeros(225,np.uint8)
    if nocc==0:near[112]=1
    else:
        for i in range(nocc):
            idx=occupied[i];r=idx//15;c=idx%15
            for dr in (-2,-1,0,1,2):
                for dc in (-2,-1,0,1,2):
                    rr=r+dr;cc=c+dc
                    if 0<=rr<15 and 0<=cc<15 and board[rr*15+cc]==0:
                        near[rr*15+cc]=1
    return near

@njit(cache=True)
def choose(board,occupied,nocc,side,last_self,style,rng,epsilon):
    near=get_candidates(board,occupied,nocc)
    # A legal tactical move always overrides learned/style scores.
    for i in range(225):
        if near[i]==1 and winning_if(board,i,side):return i,rng
    opponent=3-side
    forced=-1;threats=0
    for i in range(225):
        if near[i]==1 and winning_if(board,i,opponent):
            if forced<0:forced=i
            threats+=1
    if forced>=0:return forced,rng
    best=-1;best_score=-1e18
    for i in range(225):
        if near[i]==0:continue
        att=placement(board,i,side);defn=placement(board,i,opponent)
        central=14-abs(i//15-7)-abs(i%15-7)
        bonus=0
        if last_self>=0:
            dr=abs(i//15-last_self//15);dc=abs(i%15-last_self%15)
            if (dr==1 and dc==2) or (dr==2 and dc==1):bonus=style
        rng=xor_shift(rng)
        noise=((rng%2000)-1000)*epsilon/1000
        score=att*12+defn*10+central+bonus+noise
        if score>best_score:
            best_score=score;best=i
    return best,rng

@njit(cache=True)
def play(style_black,style_white,seed,epsilon, max_turns=90):
    board=np.zeros(225,np.int8)
    occupied=np.empty(225,np.int16)
    last_self=np.array([-1,-1],np.int32)
    rng=np.uint32(seed)
    for ply in range(max_turns):
        side=1+(ply%2)
        style=style_black if side==1 else style_white
        pos,rng=choose(board,occupied,ply,side,last_self[side-1],style,rng,epsilon)
        if pos<0:return 0,ply
        board[pos]=side;occupied[ply]=pos;last_self[side-1]=pos
        if line_win(board,pos,side):return side,ply+1
    return 0,max_turns

@njit(cache=True)
def tournament(style,n_games,seedstart,epsilon):
    wins=0;loss=0;draw=0;turns=0
    for i in range(n_games):
        seed=seedstart+i*7919
        if i%2==0:
            won,p=play(style,0,seed,epsilon)
            actor=1
        else:
            won,p=play(0,style,seed,epsilon)
            actor=2
        turns+=p
        if won==0:draw+=1
        elif won==actor:wins+=1
        else:loss+=1
    return wins,loss,draw,turns

def main():
    path=Path('/mnt/data/VeilLink-GomokuLearning-20261031-132217.vltrain.json')
    j=json.loads(path.read_text())
    games=j['payload']['recentGames']
    valid=0;knights=0;trans=0;humans=0;illegal=0;win_end_games=0
    for g in games:
        board=np.zeros(225,np.int8); last=-1;ended=False
        for p,action in enumerate(g['actions']):
            side=1 if action.startswith('h') else 2
            index=int(action[1:]);expected=1+(p%2)
            if not(0<=index<225) or board[index]!=0 or side!=expected or ended:
                illegal+=1;break
            if side==1:
                humans+=1
                if last!=-1:
                    dr=abs(index//15-last//15);dc=abs(index%15-last%15)
                    knights+=((dr==1 and dc==2) or (dr==2 and dc==1));trans+=1
                last=index
            board[index]=side
            if line_win(board,index,side):ended=True
        else:valid+=1
        if ended:win_end_games+=1
    print('real_replay',dict(games=len(games),valid_alternating_records=valid,illegal_or_post_terminal=illegal,host_moves=humans,knight_moves=knights,transitions=trans,terminal_position_records=win_end_games),flush=True)
    t=time.perf_counter()
    _=play(0,0,12345,0.0)
    print('jit_compile_seconds',round(time.perf_counter()-t,2),flush=True)
    weights=[0,50,200,800,3200]
    # Train split: 10k matches per candidate, paired alternate colors, deterministic seed partition.
    train={}
    for w in weights:
        t=time.perf_counter();win,loss,draw,turn=tournament(w,10000,1000000+25171*w,75.0)
        train[str(w)]={"win":int(win),"loss":int(loss),"draw":int(draw),"total":10000,"avg_turns":round(float(turn)/10000,2)}
        print('train',w,train[str(w)],'elapsed',round(time.perf_counter()-t,1),flush=True)
    # Promotion: lower bound on win difference. If can't prove non-regression, keep style=0.
    def lower95(o):
        n=o['total']; val=(o['win']+0.5*o['draw'])/n
        return val-1.96*((val*(1-val)/n)**0.5)
    chosen=max(weights,key=lambda w:(lower95(train[str(w)]),-w))
    # Reject a change if training advantage not robust (>=50% LCB); baseline always safe.
    if chosen!=0 and lower95(train[str(chosen)])<0.50:chosen=0
    val={}
    for w in [0,chosen,200,800,3200]:
        if str(w) in val:continue
        t=time.perf_counter();win,loss,draw,turn=tournament(w,2500,15000000+1103*w,75.0)
        val[str(w)]={"win":int(win),"loss":int(loss),"draw":int(draw),"total":2500,"avg_turns":round(float(turn)/2500,2)}
        print('validation',w,val[str(w)],'elapsed',round(time.perf_counter()-t,1),flush=True)
    # Tactical oracle tests on legal partial move sequences using random training simulator.
    tactical={'must_win':0,'must_block':0,'fail_win':0,'fail_block':0}
    for pattern in range(8):
        board=np.zeros(225,np.int8);occ=np.empty(225,np.int16)
        # horizontal / vertical / diagonal threats and rotations, place isolated opponent stones
        c=3+pattern%5;r=3+pattern%5
        if pattern%4==0:coords=[(r,c+k) for k in range(4)]
        elif pattern%4==1:coords=[(r+k,c) for k in range(4)]
        elif pattern%4==2:coords=[(r+k,c+k) for k in range(4)]
        else:coords=[(r+k,c+3-k) for k in range(4)]
        for k,(rr,cc) in enumerate(coords):board[rr*15+cc]=1;occ[k]=rr*15+cc
        for side in (1,2):
            idx,_=choose(board,occ,4,side,-1,3200,np.uint32(9999),0)
            if side==1:
                tactical['must_win']+=1
                if idx<0 or not winning_if(board,idx,1):tactical['fail_win']+=1
            else:
                tactical['must_block']+=1
                if idx<0 or not winning_if(board,idx,1):tactical['fail_block']+=1
    report={"identity":"VeilLink 27.1 Build63 offline surrogate tactical self-play, not trained native Swift model", "rules":"15x15 freestyle five-in-a-row, alternating players, 90-ply match cap", "source_export_sha256":hashlib.sha256(path.read_bytes()).hexdigest(), "source_records":len(games), "replay_valid":valid,"replay_invalid":illegal,"host_knight_ratio":knights/trans if trans else 0, "train_games_per_weight":10000,"weights":weights,"training_matches":train,"selection_rule":"choose max lower 95% point win rate, require lower bound >= 0.50 else style=0", "selected_style_weight":chosen,"validation_matches":val,"tactical_oracle":tactical,"caveats":["Synthetic surrogate Gomoku policy is not VeilLink Swift/GomokuBot", "Shared teacher heuristics do not prove strength vs Rapfi or humans", "No pretrained neural network or native weights produced", "Style cannot override immediate win/block; multi-threat forced loss is sometimes unavoidable", "No results promoted into iOS app"],"seed_train_start":1000000,"seed_validation_start":987654321}
    out=Path('/mnt/data/VeilLink-Gomoku-SelfPlay-20261031-result.json')
    out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print('report',out, 'training_total',len(weights)*10000,'validation_total',len(val)*2500,flush=True)
if __name__=='__main__':main()

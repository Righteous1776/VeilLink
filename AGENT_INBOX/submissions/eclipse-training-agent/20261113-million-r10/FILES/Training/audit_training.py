#!/usr/bin/env python3
"""Independent dataset identity, label and Swift export checks. No private data output."""
import argparse,collections,hashlib,importlib.util,json,pathlib,subprocess,time
import numpy as np
F=26;COLS=34

def win_points(b,side):
 out=set()
 for idx,v in enumerate(b):
  if v:continue
  r,c=divmod(idx,15)
  for dr,dc in [(1,0),(0,1),(1,1),(1,-1)]:
   n=1
   for sign in [-1,1]:
    rr,cc=r+dr*sign,c+dc*sign
    while 0<=rr<15 and 0<=cc<15 and b[rr*15+cc]==side:n+=1;rr+=dr*sign;cc+=dc*sign
   if n>=5:out.add(idx);break
 return out

def fork_points(b,side):
 out=set()
 for idx,v in enumerate(b):
  if v:continue
  b[idx]=side
  if len(win_points(b,side))>=2:out.add(idx)
  b[idx]=0
 return out

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--work',required=True);ap.add_argument('--swift-executable',required=True);ap.add_argument('--report',required=True);args=ap.parse_args();start=time.time();w=pathlib.Path(args.work)
 boards=[bytes(int(c) for c in l.strip()) for l in (w/'boards.txt').read_text().splitlines()]
 splits=np.load(w/'board_splits.npy');raw=np.memmap(w/'candidates.f32',dtype=np.float32,mode='r').reshape(-1,COLS)
 base=np.arange(225).reshape(15,15);maps=[np.rot90(base,k).ravel() for k in range(4)]+[np.rot90(np.fliplr(base),k).ravel() for k in range(4)]
 inv=[np.argsort(m) for m in maps];pair_counts=[0,0,0];dups=[0,0,0];symmetric=[0,0,0];rows=np.bincount(raw[:,F+1].astype(np.int32),minlength=len(boards));seen=set();offset=0
 for no,bb in enumerate(boards):
  b=np.frombuffer(bb,dtype=np.uint8);assert bb==min(b[m].tobytes() for m in maps);assert bb not in seen;seen.add(bb)
  empties=np.flatnonzero(b==0);d=raw[offset:offset+len(empties)];offset+=len(empties)
  assert np.all(d[:,F+1]==no) and np.array_equal(d[:,F+2].astype(int),empties) and rows[no]==len(empties)
  sym=[iv for mp,iv in zip(maps,inv) if np.array_equal(b[mp],b)]
  orbit={min(int(iv[i]) for iv in sym) for i in empties};s=int(splits[no]);pair_counts[s]+=len(orbit);dups[s]+=len(empties)-len(orbit);symmetric[s]+=len(sym)>1
 assert offset==len(raw)
 # The array actually supplied to fit must contain one representative per
 # D4 board+action orbit, not merely have that count in a report.
 unique_raw=np.memmap(w/'candidates_d4_unique.f32',dtype=np.float32,mode='r').reshape(-1,COLS)
 unique_counts=np.bincount(splits[unique_raw[:,F+1].astype(np.int32)],minlength=3)
 assert np.array_equal(unique_counts,pair_counts)
 unique_offset=0
 for no,bb in enumerate(boards):
  b=np.frombuffer(bb,dtype=np.uint8);empty=np.flatnonzero(b==0)
  sym=[iv for mp,iv in zip(maps,inv) if np.array_equal(b[mp],b)]
  reps=sorted({min(int(iv[i]) for iv in sym) for i in empty})
  d=unique_raw[unique_offset:unique_offset+len(reps)];unique_offset+=len(reps)
  assert np.all(d[:,F+1]==no) and np.array_equal(d[:,F+2].astype(int),reps)
 assert unique_offset==len(unique_raw)
 raw=unique_raw
 # Additional independent brute-force check of the tactical label components.
 # Preexisting immediate wins can affect the definition, so check nonforced
 # positions only, exactly as the headline heldout metric specifies.
 rng=np.random.default_rng(41676);eligible=np.flatnonzero(raw[:,F+6]==1);groups=[eligible,np.flatnonzero((raw[:,F+6]==1)&(raw[:,F+3]>0)),np.flatnonzero((raw[:,F+6]==1)&(raw[:,F+5]>0)&(raw[:,F+4]==0)),np.flatnonzero((raw[:,F+6]==1)&(raw[:,F+4]>0))]
 sample=np.unique(np.concatenate([rng.choice(group,min(12,len(group)),replace=False) for group in groups if len(group)]));label_fail=[];ownfork_checked=0
 for row_no in sample:
  row=raw[row_no];b=list(boards[int(row[F+1])]);i=int(row[F+2]);b[i]=1
  risk=len(fork_points(b,2));wins=len(win_points(b,1));ownfork=len(fork_points(b,1))
  # If our hypothetical move already creates an immediate own five, the
  # two-ply fork teacher is irrelevant; nonforced parent still permits this
  # only if detector definition changed, and must be reported explicitly.
  if wins==0:ownfork_checked+=1
  if (risk,wins)!=(int(row[F+3]),int(row[F+4])) or (wins==0 and ownfork!=int(row[F+5])):label_fail.append({'row':int(row_no),'expected':[risk,wins,ownfork],'stored':[int(row[F+3]),int(row[F+4]),int(row[F+5])]})
 # Swift real-board parity, color inversion, and D4 invariance.
 fixtures=[json.loads(l) for l in (w/'parity.jsonl').read_text().splitlines()]
 # Preserve the original pilot's same 2000 private inputs as an extra fixed
 # cohort, with expected predictions recomputed by final sklearn model.
 prior=w/'pilot_model'/'parity.jsonl'
 if prior.exists():fixtures.extend(json.loads(l) for l in prior.read_text().splitlines())
 import joblib
 model=joblib.load(w/'fitted_model.joblib');expected=model.predict(np.asarray([x['features'] for x in fixtures],dtype=np.float32))
 for x,pred in zip(fixtures,expected):x['prediction']=float(pred);x['score']=int(np.clip(pred*12,-20000,20000))
 expanded=[]
 for item in fixtures:
  expanded.append(item)
  alt=dict(item);alt['cells']=[0 if v==0 else 3-v for v in item['cells']];alt['side']=2;expanded.append(alt)
 for item in fixtures[:64]:
  b=np.asarray(item['cells']);i=item['index']
  for mp,iv in zip(maps,inv):
   for side in [1,2]:
    other=dict(item);other['cells']=[int(v) if side==1 or v==0 else 3-int(v) for v in b[mp]];other['index']=int(iv[i]);other['side']=side;expanded.append(other)
 payload=''.join(json.dumps(x,separators=(',',':'))+'\n' for x in expanded)
 run=subprocess.run([args.swift_executable],input=payload,text=True,capture_output=True,check=True)
 outputs=[json.loads(l) for l in run.stdout.splitlines()];assert len(outputs)==len(expanded)
 feature_bad=score_bad=0;max_prediction_error=0.
 for x,y in zip(expanded,outputs):
  feature_bad+=x['features']!=y['features'];score_bad+=x['score']!=y['score'];max_prediction_error=max(max_prediction_error,abs(x['prediction']-y['prediction']))
 report={'all_pre_dedup_candidate_rows':len(raw_all) if 'raw_all' in locals() else int(sum(rows)),'actual_fitted_array_rows':len(raw),'actual_fitted_rows_by_split':unique_counts.tolist(),'actual_fit_array_matches_full_d4_board_action_orbits':True,'all_candidate_pairs_exact_canonical_board_action_unique':True,'d4_canonical_board_identity_overlap_between_splits':0,'d4_board_action_orbits_by_split':pair_counts,'symmetry_equivalent_action_redundancy_by_split':dups,'boards_with_nontrivial_automorphism_by_split':symmetric,'independent_bruteforce_teacher_rows':len(sample),'teacher_label_mismatches':len(label_fail),'own_fork_checks_without_preexisting_immediate_wins':ownfork_checked,'positive_opponent_fork_cases':int(np.sum(raw[sample,F+3]>0)),'positive_own_fork_cases':int(np.sum(raw[sample,F+5]>0)),'positive_completion_cases':int(np.sum(raw[sample,F+4]>0)),'teacher_label_mismatch_details':label_fail,'swift_fixture_rows':len(expanded),'swift_original_private_fixture_rows':len(fixtures),'swift_color_inversion_rows':len(fixtures),'swift_additional_d4_color_rows':64*8*2,'swift_feature_mismatches':feature_bad,'swift_integer_score_mismatches':score_bad,'max_float_prediction_error':max_prediction_error,'wall_seconds':time.time()-start,'limitations':'Full trace D4 families and exact board identity isolation; no claim of opening-connected-component isolation. Tactical teacher heuristic, not minimax. No private boards in this aggregate report.'}
 pathlib.Path(args.report).write_text(json.dumps(report,indent=2));print(json.dumps(report));assert not label_fail and feature_bad==0 and score_bad==0
if __name__=='__main__':main()

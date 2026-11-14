#!/usr/bin/env python3
"""Real-game counterfactual training, never counterfeit native matches.
Raw histories and model binaries stay outside Git in --work.
"""
import argparse,base64,collections,hashlib,json,os,pathlib,re,subprocess,time
os.environ.setdefault('OMP_NUM_THREADS','3')
os.environ.setdefault('OPENBLAS_NUM_THREADS','3')
import numpy as np
from sklearn.ensemble import HistGradientBoostingRegressor

FEATURE_NAMES=['own_window1','own_window2','own_window3','own_window4','enemy_window1','enemy_window2','enemy_window3','enemy_window4','own_run','enemy_run','own_open3','enemy_open3','own_four','enemy_four','own_near1','enemy_near1','own_near2','enemy_near2','center','edge','occupied','own_axes3','enemy_axes3','own_cross','enemy_cross','bias']
F=len(FEATURE_NAMES);COLS=F+8

def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def transforms():
 a=np.arange(225).reshape(15,15)
 return [np.rot90(a,k).ravel() for k in range(4)]+[np.rot90(np.fliplr(a),k).ravel() for k in range(4)]
MAPS=transforms()
INV=[np.argsort(m) for m in MAPS]
def canon_trace(moves):return min(bytes(int(inv[i]) for i in moves) for inv in INV)
def canon_board(board,side):
 b=np.asarray(board,dtype=np.uint8);b=np.where(b==0,0,np.where(b==side,1,2)).astype('uint8')
 return min(b[m].tobytes() for m in MAPS)
def win(b,i,side):
 r,c=divmod(i,15)
 for dr,dc in [(1,0),(0,1),(1,1),(1,-1)]:
  n=1
  for s in [-1,1]:
   rr,cc=r+s*dr,c+s*dc
   while 0<=rr<15 and 0<=cc<15 and b[rr*15+cc]==side:n+=1;rr+=s*dr;cc+=s*dc
  if n>=5:return True
 return False

def verify_owner(p):
 raw=pathlib.Path(p).read_text();d=json.loads(raw)
 assert d['format']=='veillink.board-learning.export.v1'
 assert d['checksumAlgorithm']=='fnv1a64-canonical-json'
 start=re.search(r'"payload"\s*:',raw).end()
 while raw[start].isspace():start+=1
 _,end=json.JSONDecoder().raw_decode(raw,start)
 # Preserve Swift sorted-key ordering AND numeric lexemes. Remove only JSON
 # whitespace outside strings, rather than reserializing through Python floats.
 compact=[];quoted=False;escaped=False
 for c in raw[start:end]:
  if quoted:
   compact.append(c)
   if escaped:escaped=False
   elif c=='\\':escaped=True
   elif c=='"':quoted=False
  elif c=='"':quoted=True;compact.append(c)
  elif not c.isspace():compact.append(c)
 checksum=14695981039346656037
 for v in ''.join(compact).encode():checksum=((checksum^v)*1099511628211)&((1<<64)-1)
 assert format(checksum,'x')==d['payloadChecksum'],'owner export FNV mismatch'
 return d

AUDITED_PARTIALS={
 'd5cf13940bbb84dc937783700aa129303c4ec1d54a781992099675c3e6325d8b':{11,12,18,65},
 '050f5abbac2c3f7991db5dbcad4b4d1bd33f49eb1aeeacb5025b17d0696ce325':{29,32,33},
}
def prepare(args,w):
 traces=[];source_stats=[]
 for file_no,p in enumerate(args.owner):
  d=verify_owner(p);counts=collections.Counter();digest=sha(p)
  assert digest in AUDITED_PARTIALS,'new owner input requires native position-hash coverage audit'
  excluded=AUDITED_PARTIALS[digest]
  for seq,g in enumerate(d['payload']['recentGames'],1):
   if seq in excluded:counts['partial_restore_fragment_excluded']+=1;continue
   if g['game']!='gomoku':continue
   first=g['actions'][0][0] if g['actions'] else 'h';moves=[];b=[0]*225;terminal=False
   for ply,a in enumerate(g['actions']):
    assert a[0]==(first if ply%2==0 else ('a' if first=='h' else 'h'))
    i=int(a[1:]);assert 0<=i<225 and b[i]==0 and not terminal
    side=1+ply%2;b[i]=side;moves.append(i);terminal=win(b,i,side)
   if not terminal:counts['nonterminal_excluded_from_owner_supervision']+=1;continue
   expected=('humanWon' if g['actions'][-1][0]=='h' else 'aiWon');assert g['result']==expected
   traces.append((tuple(moves),'owner'));counts['verified_terminal']+=1
  source_stats.append({'name':pathlib.Path(p).name,'sha256':sha(p),'counts':dict(counts),'payload_fnv_verified':True,'payload_fnv':d['payloadChecksum']})
 d=json.loads(pathlib.Path(args.seed).read_text());fnv=14695981039346656037
 assert d['format']=='veillink.native-gomoku-real-selfplay.v1' and d['count']==len(d['records'])
 for rec in d['records']:
  for v in f"{rec['s']}|{rec['r']}|{rec['m']}\n".encode():fnv=((fnv^v)*1099511628211)&((1<<64)-1)
  moves=tuple(base64.b64decode(rec['m']));b=[0]*225;terminal=False
  for ply,i in enumerate(moves):
   assert i<225 and b[i]==0 and not terminal
   side=1+ply%2;b[i]=side;terminal=win(b,i,side)
  assert terminal or len(moves)==225
  assert rec['r']==('d' if not terminal else 'h' if side==1 else 'a')
  traces.append((moves,'native_seed'))
 assert format(fnv,'x')==d['fnv1a64']
 source_stats.append({'name':pathlib.Path(args.seed).name,'sha256':sha(args.seed),'verified_terminal':len(d['records']),'engine_revision':d['engineRevision'],'fnv_verified':True})
 # Full canonical traces identify games up to D4. Incomplete owner fragments are
 # excluded rather than linked by guessed starting positions.
 families={}
 for moves,source in traces:
  key=canon_trace(moves)
  if key not in families:families[key]={'moves':moves,'sources':set()}
  families[key]['sources'].add(source)
 # Family hash assigns whole games before board extraction, never random rows.
 board_splits=[{}, {}, {}];family_counts=collections.Counter()
 for key,data in families.items():
  h=int.from_bytes(hashlib.sha256(b'ECLIPSE-R10-split-v1'+key).digest()[:8],'big')%100
  split=0 if h<80 else 1 if h<90 else 2
  family_counts[split]+=1;b=[0]*225
  for ply,idx in enumerate(data['moves']):
   # Empty board has only center as native root; no useful ordering target.
   if ply>=1:
    cb=canon_board(b,1+ply%2)
    board_splits[split].setdefault(cb,0);board_splits[split][cb]|=(1 if 'owner' in data['sources'] else 0)|(2 if 'native_seed' in data['sources'] else 0)
   b[idx]=1+ply%2
 # Retain training boards; quarantine evaluation occurrences also seen in train.
 # Validation wins conflicts with test. This guarantees side-relative D4 identity
 # disjointness IN ADDITION to full-game family disjointness.
 collisions={}
 for s in [1,2]:
  for prior in range(s):
   shared=set(board_splits[s])&set(board_splits[prior]);collisions[f'{s}_vs_{prior}']=len(shared)
   for k in shared:del board_splits[s][k]
 boards=[];splits=[];sources=[]
 for s,items in enumerate(board_splits):
  for b,src in sorted(items.items()):boards.append(b);splits.append(s);sources.append(src)
 (w/'boards.txt').write_text(''.join(''.join(str(v) for v in b)+'\n' for b in boards))
 np.save(w/'board_splits.npy',np.asarray(splits,dtype=np.uint8));np.save(w/'board_sources.npy',np.asarray(sources,dtype=np.uint8))
 info={'sources':source_stats,'actual_replayed_games':len(traces),'unique_d4_game_families':len(families),'game_family_split':dict(family_counts),'unique_d4_boards_split':[len(x) for x in board_splits],'eval_shared_boards_removed':collisions,'feature_names':FEATURE_NAMES,'raw_privacy':'Raw games/boards/candidates exist only in external work directory, not Inbox.'}
 (w/'prepare.json').write_text(json.dumps(info,indent=2));return info

SWIFT_FEATURES=r'''
    static func features(cells: [UInt8], index: Int, side: UInt8) -> [Double] {
        guard cells.count == 225, index >= 0, index < 225, cells[index] == 0, side == 1 || side == 2 else { return [Double](repeating: 0, count: 26) }
        let enemy: UInt8 = side == 1 ? 2 : 1
        let r = index / 15, c = index % 15
        let directions = [(1,0),(0,1),(1,1),(1,-1)]
        func valid(_ r: Int, _ c: Int) -> Bool { r >= 0 && r < 15 && c >= 0 && c < 15 }
        var x = [Double](repeating: 0, count: 26)
        for (dr,dc) in directions {
            for offset in 0..<5 {
                let rr = r - offset * dr, cc = c - offset * dc
                guard valid(rr,cc), valid(rr+4*dr,cc+4*dc) else { continue }
                var own = 0, other = 0
                for k in 0..<5 {
                    let v = cells[(rr+k*dr)*15+cc+k*dc]
                    if v == side { own += 1 }; if v == enemy { other += 1 }
                }
                if other == 0 && own >= 1 && own <= 4 { x[own-1] += 1 }
                if own == 0 && other >= 1 && other <= 4 { x[4+other-1] += 1 }
            }
        }
        var ownAxes = 0, enemyAxes = 0
        for (dr,dc) in directions {
            var own = 1, other = 1, ownOpen = 0, otherOpen = 0
            for sign in [-1,1] {
                var rr = r + sign*dr, cc = c + sign*dc
                while valid(rr,cc) && cells[rr*15+cc] == side { own += 1; rr += sign*dr; cc += sign*dc }
                if valid(rr,cc) && cells[rr*15+cc] == 0 { ownOpen += 1 }
                rr = r + sign*dr; cc = c + sign*dc
                while valid(rr,cc) && cells[rr*15+cc] == enemy { other += 1; rr += sign*dr; cc += sign*dc }
                if valid(rr,cc) && cells[rr*15+cc] == 0 { otherOpen += 1 }
            }
            x[8] = max(x[8],Double(own)); x[9] = max(x[9],Double(other))
            if own >= 3 && ownOpen == 2 { x[10] += 1 }; if other >= 3 && otherOpen == 2 { x[11] += 1 }
            if own >= 4 && ownOpen >= 1 { x[12] += 1 }; if other >= 4 && otherOpen >= 1 { x[13] += 1 }
            if own >= 3 && ownOpen >= 1 { ownAxes += 1 }; if other >= 3 && otherOpen >= 1 { enemyAxes += 1 }
            for sign in [-1,1] { for distance in 1...2 {
                let rr = r+sign*distance*dr, cc = c+sign*distance*dc
                guard valid(rr,cc) else { continue }
                let v = cells[rr*15+cc]
                if v == side { x[distance == 1 ? 14 : 16] += 1 }; if v == enemy { x[distance == 1 ? 15 : 17] += 1 }
            }}
        }
        x[18] = Double(15-abs(r-7)-abs(c-7)); x[19] = Double(min(min(r,c),min(14-r,14-c)))
        x[20] = Double(cells.reduce(0) { $0 + ($1 == 0 ? 0 : 1) })
        x[21] = Double(ownAxes); x[22] = Double(enemyAxes)
        x[23] = x[2]*(x[2]-1)/2; x[24] = x[6]*(x[6]-1)/2; x[25] = 1
        return x
    }
'''

def export_swift(model,path):
 nodes=[];roots=[]
 for pred in model._predictors:
  tree=pred[0].nodes;offset=len(nodes);roots.append(offset)
  for n in tree:
   nodes.append((int(n['feature_idx']),float(n['num_threshold']),int(n['left'])+offset,int(n['right'])+offset,float(n['value']),bool(n['is_leaf'])))
 text='''import Foundation
/// Fitted only on replayed real-game counterfactual candidate records.
/// Reorders legal search candidates; never substitutes for a tactical proof.
enum EclipseTrainedOrdering {
    static let modelID = "ECLIPSE-R10-real-candidate-histgb-v1"
    static let outputMultiplier = 12.0
    private struct Node { let feature: Int; let threshold: Double; let left: Int; let right: Int; let value: Double; let leaf: Bool }
'''
 text+=f'    private static let baseline = {float(model._baseline_prediction[0,0])!r}\n'
 text+='    private static let roots: [Int] = '+str(roots)+'\n'
 text+='    private static let nodes: [Node] = {\n        var all = [Node]()\n        all.reserveCapacity('+str(len(nodes))+')\n'
 for offset in range(0,len(nodes),24):
  text+='        all.append(contentsOf: [\n'
  for f,t,l,r,v,leaf in nodes[offset:offset+24]:text+=f'            Node(feature: {f}, threshold: {t!r}, left: {l}, right: {r}, value: {v!r}, leaf: {str(leaf).lower()}),\n'
  text+='        ])\n'
 text+='        return all\n    }()\n'+SWIFT_FEATURES
 text+='''
    static func rawPrediction(_ x: [Double]) -> Double {
        var result = baseline
        for root in roots {
            var node = root
            while !nodes[node].leaf {
                let n = nodes[node]
                node = x[n.feature] <= n.threshold ? n.left : n.right
            }
            result += nodes[node].value
        }
        return result
    }
    static func score(cells: [UInt8], index: Int, side: UInt8) -> Int {
        guard cells.count == 225, index >= 0, index < 225, cells[index] == 0 else { return 0 }
        return Int(max(-20_000, min(20_000, rawPrediction(features(cells: cells, index: index, side: side)) * outputMultiplier)))
    }
}
'''
 path.write_text(text);return len(nodes)

def metrics(data,pred):
 out={};ids=data[:,F+1].astype(int);unique,starts=np.unique(ids,return_index=True);ends=np.r_[starts[1:],len(ids)]
 sums=collections.defaultdict(float);n=0
 for start,end in zip(starts,ends):
  d=data[start:end]
  if d[0,F+6]!=1:continue
  n+=1;baseline=(18*d[:,14]+12*d[:,15]+5*d[:,16]+3*d[:,17])*8+d[:,18]
  indices={'baseline':int(np.argmax(baseline)),'trained':int(np.argmax(pred[start:end])),'teacher':int(np.argmax(d[:,F]))}
  best=float(np.max(d[:,F]));safe=bool(np.any(d[:,F+3]==0))
  for name,i in indices.items():
   row=d[i];sums[name+'_teacher_utility']+=float(row[F]);sums[name+'_regret']+=best-float(row[F]);sums[name+'_safe']+=row[F+3]==0;sums[name+'_fork_risk']+=row[F+3];sums[name+'_optimal']+=abs(float(row[F])-best)<1e-5
  sums['changed_decision']+=indices['baseline']!=indices['trained'];sums['any_safe_candidate']+=safe
 return {'nonforced_boards':n,**{k:(int(v) if k.endswith('_safe') or k.endswith('_optimal') or k in ['changed_decision','any_safe_candidate'] else float(v/max(1,n))) for k,v in sums.items()}}

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--owner',action='append',required=True);ap.add_argument('--seed',required=True);ap.add_argument('--work',required=True);ap.add_argument('--report-dir',required=True);args=ap.parse_args()
 w=pathlib.Path(args.work);w.mkdir(parents=True,exist_ok=True);reportdir=pathlib.Path(args.report_dir);reportdir.mkdir(parents=True,exist_ok=True);start=time.time()
 info=prepare(args,w);print(json.dumps(info),flush=True)
 source=pathlib.Path(__file__).with_name('candidate_teacher.cpp');exe=w/'candidate_teacher'
 subprocess.run(['g++','-O3','-std=c++17',str(source),'-o',str(exe)],check=True)
 subprocess.run([str(exe),str(w/'boards.txt'),str(w/'candidates.f32')],check=True)
 raw_all=np.memmap(w/'candidates.f32',dtype=np.float32,mode='r').reshape(-1,COLS)
 # Canonical BOARD identity alone leaves equivalent action cells on symmetric
 # boards. Remove those automorphism-equivalent alternatives BEFORE fitting.
 # Verify their features AND teacher labels equal their chosen orbit representative.
 keep=np.zeros(len(raw_all),dtype=bool);offset=0;removed=[0,0,0]
 board_lines=(w/'boards.txt').read_text().splitlines();board_splits=np.load(w/'board_splits.npy')
 for bid,line in enumerate(board_lines):
  b=np.fromiter((int(c) for c in line),dtype=np.uint8);empties=np.flatnonzero(b==0)
  stabilizers=[iv for mp,iv in zip(MAPS,INV) if np.array_equal(b[mp],b)]
  representatives={int(i):min(int(iv[i]) for iv in stabilizers) for i in empties}
  row_index={int(i):offset+k for k,i in enumerate(empties)}
  for k,i in enumerate(empties):
   representative=representatives[int(i)]
   if int(i)==representative:keep[offset+k]=True
   else:
    a=raw_all[offset+k];r=raw_all[row_index[representative]]
    assert np.array_equal(a[:F+1],r[:F+1]) and np.array_equal(a[F+3:],r[F+3:]),'D4 orbit teacher/features mismatch'
    removed[int(board_splits[bid])]+=1
  offset+=len(empties)
 assert offset==len(raw_all)
 raw=raw_all[keep];raw.tofile(w/'candidates_d4_unique.f32')
 info['pre_dedup_candidate_rows']=len(raw_all);info['d4_equivalent_action_rows_removed_before_fit']=removed
 info['training_rows_are_unique_full_d4_board_action_orbits']=True
 splits=np.load(w/'board_splits.npy');row_splits=splits[raw[:,F+1].astype(np.int32)]
 train=raw[row_splits==0];val=raw[row_splits==1];test=raw[row_splits==2]
 info['candidate_rows_split']=[len(train),len(val),len(test)];info['training_rows_are_unique_canonical_board_action_pairs']=True
 print('Training',info['candidate_rows_split'],flush=True)
 # Every training candidate changes the fitted objective. No duplication or
 # repeated epochs are counted as extra data. Equal total board weighting.
 ids=train[:,F+1].astype(int);counts=np.bincount(ids);weights=1.0/counts[ids]
 weights*=np.where(train[:,F+7]>0,3.0,1.0);weights*=len(weights)/weights.sum()
 best=None;bestkey=None;sweep=[]
 for iterations in [24,48]:
  model=HistGradientBoostingRegressor(max_iter=iterations,max_leaf_nodes=15,max_depth=4,max_bins=64,l2_regularization=8,learning_rate=.15,early_stopping=False,random_state=20261113)
  model.fit(train[:,:F],train[:,F],sample_weight=weights)
  vp=model.predict(val[:,:F]);m=metrics(val,vp);sweep.append({'iterations':iterations,'validation':m})
  key=(m['trained_teacher_utility'],-m['trained_fork_risk'])
  if bestkey is None or key>bestkey:bestkey=key;best=model
  print(json.dumps(sweep[-1]),flush=True)
 info['validation_sweep']=sweep;info['selected_iterations']=best.max_iter
 tp=best.predict(test[:,:F]);info['heldout_test']=metrics(test,tp)
 swiftpath=reportdir/'EclipseTrainedOrdering.swift';info['exported_tree_nodes']=export_swift(best,swiftpath)
 # Private parity data: source boards are never written into Inbox.
 rng=np.random.default_rng(20261113);take=np.sort(rng.choice(len(test),min(2000,len(test)),replace=False))
 boards=(w/'boards.txt').read_text().splitlines()
 with (w/'parity.jsonl').open('w') as f:
  pp=best.predict(test[take,:F])
  for row,pred in zip(test[take],pp):
   f.write(json.dumps({'cells':[int(x) for x in boards[int(row[F+1])]],'index':int(row[F+2]),'side':1,'features':[float(x) for x in row[:F]],'prediction':float(pred),'score':int(np.clip(pred*12,-20000,20000))},separators=(',',':'))+'\n')
 import joblib;joblib.dump(best,w/'fitted_model.joblib')
 info['teacher']='Exact counterfactual remaining enemy fork cells, own new fork multiplicity and immediate completion count plus local potential. Labels are independently computed rules, not actual moves or native search wins.'
 info['deployment']='26 integer-valued local features; up to48 depth4 trees; score=clamp(prediction*12,+-20000), identical relative-side model both colors; search candidate ordering only; guards unchanged.'
 info['limits']='No claim of million games, master labels or measured Elo. This is a bounded geometric heuristic teacher, NOT a minimax engine or proof of winning utility. Exact full-trace D4 families and exact board exclusions are disjoint, but shared initial openings or diverging trajectories are not graph-component isolated. End-to-end ECLIPSE arena required before promotion.'
 info['wall_seconds']=time.time()-start
 info['hashes']={str(p):sha(p) for p in [source,pathlib.Path(__file__),w/'boards.txt',w/'candidates.f32',w/'candidates_d4_unique.f32',w/'parity.jsonl',swiftpath]}
 (w/'training_report.json').write_text(json.dumps(info,indent=2));(reportdir/'TRAINING_METRICS.json').write_text(json.dumps(info,indent=2));print(json.dumps(info),flush=True)
if __name__=='__main__':main()

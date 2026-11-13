#!/usr/bin/env python3
"""Run native, color-swapped adjacent ECLIPSE levels and independently audit.
All binaries and complete replay evidence belong outside the Inbox.
"""
import argparse,hashlib,json,pathlib,subprocess,sys

def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--output',required=True);p.add_argument('--auditor',required=True);p.add_argument('--games',type=int,default=60);p.add_argument('--seed',type=int,default=937552101);a=p.parse_args()
 assert a.games>=2 and a.games%2==0
 out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
 # Exact depth,width,node,time,forcing limits from EclipseDifficultyPolicy.swift.
 levels=[('relaxed',(1,4,128,80,0)),('balanced',(2,6,384,180,1)),('advanced',(3,8,1000,400,2)),('master',(4,12,5000,950,3))]
 jobs=[]
 for i,((low,lb),(high,hb)) in enumerate(zip(levels,levels[1:])):
  raw=out/f'{high}-vs-{low}.jsonl';log=out/f'{high}-vs-{low}.log';stream=log.open('w')
  cmd=[a.binary,'--baseline-trained','--games',str(a.games),'--seed',str(a.seed+i),'--output',str(raw)]
  for prefix,budget in [('',hb),('baseline-',lb)]:
   for key,val in zip(['depth','width','nodes','milliseconds','forcing-depth'],budget):cmd += ['--'+prefix+key,str(val)]
  proc=subprocess.Popen(cmd,stdout=stream,stderr=stream);jobs.append((proc,stream,raw,low,high,cmd))
 manifest={'format':'veillink.eclipse.difficulty-calibration.v1','binary_sha256':sha(a.binary),'games_per_adjacent':a.games,'tier_limits':dict(levels),'matches':[]}
 for proc,stream,raw,low,high,cmd in jobs:
  code=proc.wait();stream.close()
  if code:raise RuntimeError(f'{high} vs {low} exited{code}')
  report=out/f'{high}-vs-{low}-report.json'
  subprocess.run([sys.executable,a.auditor,str(raw),'--output',str(report)],check=True)
  stats=json.loads(report.read_text());manifest['matches'].append({'lower':low,'higher':high,'raw_sha256':sha(raw),'command':cmd,'report':stats})
 (out/'DIFFICULTY_METRICS.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()

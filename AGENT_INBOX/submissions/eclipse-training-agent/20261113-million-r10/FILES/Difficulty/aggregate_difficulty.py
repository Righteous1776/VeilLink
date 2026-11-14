#!/usr/bin/env python3
"""Aggregate predeclared tier tests; never treats budget levels as Elo ranks."""
import argparse,hashlib,json,pathlib,statistics,subprocess,sys,math

def main():
 p=argparse.ArgumentParser();p.add_argument('--initial',type=pathlib.Path,required=True);p.add_argument('--confirmation',type=pathlib.Path,required=True);p.add_argument('--auditor',required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 groups=[('balanced','relaxed'),('advanced','balanced'),('master','advanced')];result={'format':'veillink.eclipse.difficulty-calibration.v2','games':0,'matches':[],'protocol':'Same frozen trained model on both sides. Initial60 per adjacent; independent120 additional per borderline pair. No budget or model tuning.'}
 for high,low in groups:
  name=f'{high}-vs-{low}';paths=[a.initial/(name+'.jsonl')]
  if high!='advanced':paths.append(a.confirmation/(name+'.jsonl'))
  reportpath=a.output/(name+'-report.json');subprocess.run([sys.executable,a.auditor,*map(str,paths),'--output',str(reportpath)],check=True,stdout=subprocess.DEVNULL)
  report=json.loads(reportpath.read_text());raws=[json.loads(x)for path in paths for x in path.read_text().splitlines()]
  role=[]
  for flag,tier in [(True,high),(False,low)]:
   decisions=[d for r in raws for d in r['decisions']if d['challenger']==flag];ms=sorted(d['milliseconds']for d in decisions)
   role.append({'tier':tier,'decisions':len(decisions),'mean_ms':statistics.mean(ms),'p95_ms':ms[min(len(ms)-1,math.ceil(.95*len(ms))-1)],'mean_nodes':statistics.mean(d['nodes']for d in decisions)})
  result['matches'].append({'higher':high,'lower':low,'report':report,'role_metrics':role})
  result['games']+=report['games']
 result['interpretation']='Adjacent strength intervals are descriptive estimates for these seeds/budgets, not universal skill ranks. Raw paired openings are not counted as new training rows.'
 (a.output/'DIFFICULTY_METRICS_FINAL.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()

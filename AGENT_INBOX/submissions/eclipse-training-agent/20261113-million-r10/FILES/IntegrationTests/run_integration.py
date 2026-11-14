#!/usr/bin/env python3
"""Compile actual proposed GomokuBot hook plus source-extracted production deps.
All extracted files, compiler outputs and logs live in --work outside the repo.
No iOS/XCTest/build-configuration verification is implied.
"""
import argparse,hashlib,json,pathlib,subprocess

def digest(data):return hashlib.sha256(data).hexdigest()
def piece(text,start,end):return text[text.index(start):text.index(end)]

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True);ap.add_argument('--work',required=True);ap.add_argument('--swiftc',required=True);args=ap.parse_args()
 repo=pathlib.Path(args.repo).resolve();work=pathlib.Path(args.work).resolve()
 assert repo not in work.parents and work!=repo,'--work must be outside repository'
 work.mkdir(parents=True,exist_ok=True);here=pathlib.Path(__file__).resolve().parent;files=here.parent
 sources={}
 def read(relative):
  p=repo/relative;sources[relative]=digest(p.read_bytes());return p.read_text()
 mini=read('VeilLink/Core/MiniGames.swift')
 rules=piece(mini,'enum MiniGamePlayer:','enum MiniGameSessionStatus:')+piece(mini,'struct GomokuState:','enum XiangqiSide:')
 # The rule slice may include neutral code after GomokuState if production adds
 # declarations; the present baseline ends immediately before XiangqiSide.
 learning=read('VeilLink/Agent/Games/AdaptiveBoardLearning.swift')
 snapshot=piece(learning,'struct AdaptiveBoardLearningSnapshot:','extension AdaptiveBoardLearningSnapshot {')
 prediction=piece(learning,'struct AdaptiveBoardPrediction:','struct DeveloperFormationInfluence:')
 position=piece(learning,'    static func gomoku(_ state: GomokuState)','    static func xiangqi(')
 fnv=piece(learning,'    private static func fnv64(','\n}\n\nstruct AdaptiveBoardPly:')
 support='import Foundation\n'+rules+'\n'+snapshot+prediction+'\nenum AdaptiveBoardPosition {\n'+position+fnv+'\n}\n'
 controller=read('VeilLink/Agent/Games/LocalAIGameController.swift')
 support+=piece(controller,'enum BoardBotDifficulty:','/// User-directed compute preference:')
 formation=read('VeilLink/Agent/Games/GomokuFormationLearning.swift')
 support+=piece(formation,'enum GomokuFormationMode:','struct GomokuFormationCandidateRecord:')
 support_path=work/'ExtractedProductionDependencies.swift';support_path.write_text(support)
 compiler=[args.swiftc,'-O','-o',str(work/'production_hook_tests'),str(support_path),str(repo/'VeilLink/Agent/Games/GomokuCounterForkR4.swift'),str(files/'Native/GomokuBot.swift'),str(files/'Native/VeilGomokuUnifiedBridge.swift'),str(files/'Native/VeilGomokuUnifiedSearch.swift'),str(files/'Difficulty/EclipseDifficultyPolicy.swift'),str(files/'Training/EclipseTrainedOrdering.swift'),str(here/'ProductionHookTests.swift')]
 provenance={'repository_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'source_sha256':sources,'extracted_support_sha256':digest(support.encode()),'compiler':compiler,'scope':'Linux Swift local production-hook compile; no iOS/XCTest/build-resource claim'}
 for p in compiler[5:]:
  path=pathlib.Path(p)
  if path.is_file():provenance.setdefault('compiled_sha256',{})[str(path)]=digest(path.read_bytes())
 provenance['runner_sha256']=digest(pathlib.Path(__file__).read_bytes())
 (work/'PROVENANCE.json').write_text(json.dumps(provenance,indent=2))
 compiled=subprocess.run(compiler,capture_output=True,text=True);(work/'compile.log').write_text(compiled.stdout+compiled.stderr)
 if compiled.returncode:print(compiled.stderr);raise SystemExit(compiled.returncode)
 result=subprocess.run([str(work/'production_hook_tests')],capture_output=True,text=True)
 (work/'tests.log').write_text(result.stdout+result.stderr);print(result.stdout+result.stderr,end='')
 changed=[p for p,h in provenance['compiled_sha256'].items() if digest(pathlib.Path(p).read_bytes())!=h]
 if changed:print('COMPILED SOURCE CHANGED DURING TEST:',changed);raise SystemExit(3)
 raise SystemExit(result.returncode)
if __name__=='__main__':main()

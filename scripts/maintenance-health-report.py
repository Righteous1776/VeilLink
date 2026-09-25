#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re
ROOT=Path.cwd()

def exists(rel): return (ROOT/rel).is_file()
def sha(rel):
    p=ROOT/rel
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None

def plist_value(text,key):
    m=re.search(rf'<key>{re.escape(key)}</key>\s*<string>([^<]+)</string>',text)
    return m.group(1) if m else None
info=(ROOT/'VeilLink/Resources/Info.plist').read_text(encoding='utf-8') if exists('VeilLink/Resources/Info.plist') else ''
critical=[
 'VeilLink/Agent/Integration/VeilAppControlPlane.swift',
 'VeilLink/Agent/Integration/VeilAutoRegulation.swift',
 'VeilLink/Agent/Language/VeilTalkLiteRuntime.swift',
 'scripts/verify-local-control-plane.py','scripts/verify-control-plane-v2.py',
 'scripts/verify-autoregulation-r7.py','scripts/verify-maintenance-r8.py',
]
report={
 'schema':1,
 'version':plist_value(info,'CFBundleShortVersionString'),
 'build':plist_value(info,'CFBundleVersion'),
 'critical_files':{p:{'present':exists(p),'sha256':sha(p)} for p in critical},
 'history':{
   'r5':exists('docs/history/control-plane/V0103_R5/manifest.sha256'),
   'r6':exists('docs/history/control-plane/V0104_R6/manifest.sha256'),
   'r7':exists('docs/history/maintenance/V0105_R7/manifest.sha256'),
 },
 'experimental_history_present': any((ROOT/p).exists() for p in ['VeilLink/Agent/MaleCNS','VeilLink/Resources/VeilFlyLite.vfly','VeilLink/Resources/VeilFlyCore.vfly']),
 'maintenance':{
   'transaction_helper':exists('scripts/upgrade-transaction.py'),
   'autotune_log_dedup':'autoRegulationLastLoggedFingerprint' in ((ROOT/'VeilLink/App/AppModel.swift').read_text(encoding='utf-8') if exists('VeilLink/App/AppModel.swift') else ''),
   'feature_freeze':'0.10.6',
 },
}
print(json.dumps(report,ensure_ascii=False,indent=2,sort_keys=True))

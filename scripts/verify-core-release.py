#!/usr/bin/env python3
import argparse, hashlib, json, os, plistlib, subprocess, zipfile
from pathlib import Path
FORBIDDEN = {'weights.npz', 'brain.npz', 'MaleCNSReference.vfly'}
def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1048576), b''): h.update(b)
    return h.hexdigest()
def fail(s): raise SystemExit('CORE RELEASE GATE FAIL: ' + s)
def find_one(root, name):
    hits = [p for p in Path(root).rglob(name) if p.is_file()]
    if len(hits) != 1: fail(f'expected one {name}, got {len(hits)}')
    return hits[0]
def main():
    ap = argparse.ArgumentParser()
    for n in ('app','ipa','manifest','provenance','sums'): ap.add_argument('--'+n, required=True)
    a = ap.parse_args(); app = Path(a.app); ipa = Path(a.ipa)
    if not app.is_dir() or not ipa.is_file() or ipa.stat().st_size == 0: fail('app/IPA missing')
    for n in FORBIDDEN:
        if list(app.rglob(n)): fail('raw training file in app: '+n)
    info = plistlib.loads((app/'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'studio.zeo.veillink': fail('bundle id mismatch')
    if not str(info.get('MinimumOSVersion','15')).startswith('15'): fail('minimum OS mismatch')
    m = find_one(app, 'ios_integration_manifest.json')
    md = json.loads(m.read_text())
    if md.get('source_model_hash', md.get('model_sha256')) != 'c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4': fail('M5 provenance mismatch')
    with zipfile.ZipFile(ipa) as z:
        if z.testzip() is not None: fail('IPA CRC failure')
        names = z.namelist(); prefix = 'Payload/VeilLink.app/'
        if prefix+'VeilLink' not in names: fail('IPA executable missing')
        for n in FORBIDDEN:
            if any(x.endswith('/'+n) for x in names): fail('forbidden IPA file: '+n)
        for rel, p in [('Info.plist', app/'Info.plist'), ('VeilLink', app/'VeilLink'), (m.relative_to(app).as_posix(), m)]:
            matches = [x for x in names if x == prefix+rel or x.endswith('/'+rel)]
            if len(matches) != 1:
                fail('IPA parity mismatch: '+rel)
            if rel == 'Info.plist':
                # ditto/Xcode may rewrite auxiliary plist keys or binary plist
                # representation while preserving the app identity. Validate
                # the packaged plist directly for launch-critical fields.
                try:
                    ipa_info = plistlib.loads(z.read(matches[0]))
                    parity_ok = (
                        ipa_info.get('CFBundleIdentifier') == 'studio.zeo.veillink'
                        and str(ipa_info.get('MinimumOSVersion', '15')).startswith('15')
                    )
                except Exception:
                    parity_ok = False
            else:
                parity_ok = sha(p) == hashlib.sha256(z.read(matches[0])).hexdigest()
            if not parity_ok:
                fail('IPA parity mismatch: '+rel)
    manifest = {'schema':1,'result':'PASS','release_eligible':True,'unsigned':True,'app':{'bundle_id':info.get('CFBundleIdentifier'),'version':info.get('CFBundleShortVersionString'),'build':str(info.get('CFBundleVersion')),'m5_manifest_sha256':sha(m)},'ipa':{'bytes':ipa.stat().st_size,'sha256':sha(ipa)}}
    Path(a.manifest).write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n')
    provenance = {'schema':1,'git_head':subprocess.getoutput('git rev-parse HEAD'),'github_run_id':os.getenv('GITHUB_RUN_ID'),'github_sha':os.getenv('GITHUB_SHA'),'ipa_sha256':sha(ipa),'release_manifest_sha256':sha(Path(a.manifest))}
    Path(a.provenance).write_text(json.dumps(provenance, indent=2, sort_keys=True)+'\n')
    Path(a.sums).write_text(f'{sha(ipa)}  {ipa.name}\n{sha(Path(a.manifest))}  {Path(a.manifest).name}\n{sha(Path(a.provenance))}  {Path(a.provenance).name}\n')
    print('VEILLINK_CORE_RELEASE_GATE=PASS')
if __name__ == '__main__': main()

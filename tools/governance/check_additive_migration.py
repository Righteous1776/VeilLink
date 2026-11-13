#!/usr/bin/env python3
"""Check the migration commit preserves every baseline file and imported source."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

def check(repo, base, head):
    def tree(ref):
        raw = subprocess.check_output(['git','-C',str(repo),'ls-tree','-rz',ref])
        result = {}
        for line in filter(None, raw.split(b'\0')):
            metadata, path = line.split(b'\t', 1)
            result[path.decode()] = metadata.decode()
        return result
    before, after = tree(base), tree(head)
    changed = [p for p, obj in before.items() if after.get(p) != obj]
    if changed:
        raise ValueError('Existing files changed/deleted/mode changed: '+repr(changed))
    added = sorted(set(after)-set(before))
    if not added:
        raise ValueError('No additions')
    lockpath = 'governance/zeo_foundation/SOURCE_LOCK.json'
    lock = json.loads(subprocess.check_output(['git','-C',str(repo),'show',f'{head}:{lockpath}']))
    for item in lock['files']:
        data = subprocess.check_output(['git','-C',str(repo),'show',f"{head}:{item['path']}"])
        if hashlib.sha256(data).hexdigest() != item['installed_sha256']:
            raise ValueError('Source lock mismatch: '+item['path'])
    return {'baseline_files_preserved':len(before), 'added_files':len(added),
            'source_files_verified':len(lock['files']), 'base':base, 'head':head}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo',type=Path,default=Path('.'))
    p.add_argument('--base',required=True);p.add_argument('--head',default='HEAD')
    a=p.parse_args()
    print('ADDITIVE_MIGRATION_PASS '+json.dumps(check(a.repo,a.base,a.head),sort_keys=True))

if __name__=='__main__':main()

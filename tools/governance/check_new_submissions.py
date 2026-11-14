#!/usr/bin/env python3
"""Supplement the unchanged V1.1 workflow for newly created V1.2 proposals."""
import argparse
from pathlib import Path, PurePosixPath
import subprocess
import sys

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])

def new_roots(repo, base, head):
    changed = git(repo, 'diff', '--name-only', '-z', base, head).decode().split('\0')
    roots = set()
    for path in filter(None, changed):
        parts = PurePosixPath(path).parts
        if len(parts) >= 5 and parts[:2] == ('AGENT_INBOX', 'submissions'):
            root = '/'.join(parts[:4])
            old = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e',
                                  f'{base}:{root}/MANIFEST.md'], capture_output=True)
            if old.returncode:
                roots.add(root)
    return roots

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, default=Path('.'))
    for arg in ['base', 'head', 'head-ref', 'pr-title']:
        p.add_argument('--'+arg, required=True)
    a = p.parse_args()
    if not a.head_ref.startswith('agent-drop/'):
        print('ZEO_NEW_DROP_NOT_APPLICABLE: non-Lane PR; Owner review remains required')
        return 0
    # Bootstrap cannot attest against a policy absent from the trusted PR base.
    active = subprocess.run(['git', '-C', str(a.repo), 'cat-file', '-e',
                             f'{a.base}:AGENT_INBOX/07_LEARNING_GATE.md'], capture_output=True)
    if active.returncode:
        print('ZEO_LEARNING_NOT_ACTIVATED_AT_BASE: original V1.1 checks remain in force')
        return 0
    roots = new_roots(a.repo, a.base, a.head)
    if not roots:
        print('ZEO_LEGACY_DROP_PRESERVED: unchanged V1.1 workflow governs historical proposals')
        return 0
    # Actions checks out a detached head and may have no local main/origin HEAD.
    # Pin freshness to the actual PR base, using the upstream supported reference
    # argument; never invent a default-branch ref or weaken document/hash checks.
    sys.path.insert(0, str(a.repo.resolve()/'AGENT_INBOX/tools'))
    import inbox_gate
    original = inbox_gate.validate_study
    def pinned_study(repo, record, **kwargs):
        return original(repo, record, reference_sha=a.base, **kwargs)
    inbox_gate.validate_study = pinned_study
    try:
        inbox_gate.validate_strict(a.repo, a)
    except (inbox_gate.GateFail, inbox_gate.StudyFail, OSError, ValueError) as exc:
        print('ZEO_NEW_DROP_GATE_FAIL: '+str(exc), file=sys.stderr)
        return 2
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

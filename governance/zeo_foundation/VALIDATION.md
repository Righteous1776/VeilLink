# Local verification and delivery limits

Base: `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`. Owner scope: governance bootstrap, additions only.

Executed on 2026-11-13 with Python 3.12.14:

- `python3 -m unittest discover -s tools/governance/tests -v`: **30 tests passed**. Tests use temporary synthetic Git repositories and SQLite stores, never real messages or project databases.
- `python3 tools/governance/agent_exchange.py validate`: `VALIDATION_ERRORS=0` on the newly created empty bus.
- `python3 tools/governance/agent_exchange.py scan --task-id zeo-additive-20261113 --profile ENGINEER --lane governance`: `PENDING_REQUIRED=0`, `INFO_MATCHED=0`, `BLOCKING=0`. No message/receipt sent.
- Tracked-worktree comparison before staging: no differences from baseline. `check_additive_migration.py` passed: all 1,924 baseline files retained their original blob/mode/path; 48 imported source hashes matched. The final remote head must be checked again after delivery.

Regressions include tampered/missing/stale Git source, wrong identity/rule recall, missing study evidence, invalid binary/assets, symlink escape, product write mixed into a Lane PR, old vs new proposal routing, duplicate Session initialization, incomplete ACK/Epoch mismatch, independent broadcast receipts, actual linked replies, unauthorized Governor assignments, unreviewed memory candidates, secret rejection, and unwanted modification/deletion of old files.

These are integration regressions for the installed subset, not the entire upstream package's test inventory. No Apple/Xcode/product build, physical device, server protection audit, trusted-main dual learning PASS, main merge, IPA or release is claimed. Remote CI and PR must be read from GitHub after delivery.

```text
[ZEO-UNIFIED-REPORT]
source: live_repo
role: lane acting under explicit Owner bootstrap authorization
platform: chatgpt
runtime: remote_agent
capabilities_verified: Git/Python/local write/local tests/remote read
learning_b: partial; full new source locally present, canonical main baseline pending
learning_c: blocked against old main; synthetic 11-document fixtures pass
Task-ID: zeo-additive-20261113
Session-ID: SESSION-ZEO-20261113
branch: admin/zeo-foundation-migration-20261113
base_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
proposal_state: draft
exchange_state: none
changes: new governance/tool/adapter/template/CI files only; verify commit with additive checker
tests: 30/30 local regressions; empty Exchange validation/scan successful
risks: main activation pending; server protections unverified; incomplete portable package is intentional
next_action: existing Owner/Governor review of the actual migration Draft PR and CI
```

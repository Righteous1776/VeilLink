# V29 integration intake — exact-source preflight

Task: `VEILLINK-V29-INTEGRATION-20261107`.
Operator: Codex, acting on direct Owner request, NOT claiming a new Governor ID.
Integration preparation branch: `integration/v29-intake-20261107`.
Frozen main / rollback baseline: `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
Existing release: `v28.0-b65`; retained unchanged.

## Owner instruction and effective boundary

> 好，合并所有已经新增的功能，包括：
> 1. 大富翁的分支
> 2. Inbox 的所有分支
> 3. 新接入 0灵核模型的分支
> 4. 你现在的分支
>
> 将所有的都整合在一起，推出最新版本并建立 IPA。这又是一次大版本更新，V29。

This authorizes a new integration/release objective, superseding the earlier
dev-only/no-IPA task restriction for that objective. It does NOT mean failing
tests passed, authorize unsafe key/schema/protocol migrations, remove existing
acceptance gates or turn metadata-only Inbox drops into applied product code.
No governance registry, signing identity, secrets or source branch is changed.

## Identified inputs (not yet merged or accepted as a release batch)

| Source | Frozen SHA | Preflight / required disposition |
| --- | --- | --- |
| Current Veilopoly + Codex UI branch `dev/veilopoly` | `afa560718c2f8ac1bde0b73dcdc44a8451782c93` | Includes both UI waves, live host hookup and V4 economics. Latest portable full suite **340 cases / 1 failure**; UI121/121 passes do NOT waive it. Apple host/UI/P5 two-phone gates remain open. |
| `dev/veilopoly-manual-v5-20261108` | `1f6532697e10abdb91f68ee4c30fbcd3b76a3183` | Contains V5 economy/risk/manual ancestry; not interchangeable with current V4 + new UI. Separate branch was deliberately isolated. Full exact-head SwiftPM/Apple acceptance not established; reconcile, do not overwrite new UI with older UI files. |
| Board consolidation PR #178 | `c40613d88f7ae0350954f1c881d46014f0aaa216` | iOS CI42394304207 SUCCESS; merges R3–R8 ancestry. Do not separately reapply all its ancestors. |
| Alternative board closeout PR #179 | `1292d2c08de8c1d3734f00bb2ed940df52869d66` | CI42395678850 in progress at intake. Overlaps #178's controller, lobby and tests; different persisted search setting/API. NOT independent additive features; explicit reconciliation required. |
| LingCore/Vertex35M PR #180 | `cdd9faeaa58533be786acaa00bd89179157a7a60` | Actual 29,203,168-byte GGUF + native runtime found. Latest standard/native checks still running. Earlier real Chinese prompt yielded64 tokens,309 characters,0 Han (quality FAIL); latest bilingual prompt not yet verified. |
| Isolated LingCore contract PR #176 | `de422d23f604efd913391a599e9e8a9bcfd6599c` | Precursor to #180, not a second distinct model. Do not duplicate its boundary/runtime definitions. |
| New Inbox cancellation PR #165 | `451b8df08d86b418d8122e8b6fc152362909c6e2` | Metadata/patch proposal, not production source. Apple tests NOT_RUN per manifest; requires actual patch review/application + host regression. |
| Board Inbox replay/curriculum PR #166 | See current PR/ancestry at application | Check absorption in #178's R3–R8 stack; do not apply old proposal on top of its evolved implementation. |
| Historical Inbox branches | See V28 86-head ledger | Most already absorbed, reconciled or superseded in V28. Keep original evidence branches; do not merge old whole-file snapshots into V29. |

Sources: current GitHub refs, PR checks, #6, #168, `AGENT_INBOX/QUEUE.md` and
`docs/engineering/V28_INBOX_INTAKE_LEDGER_20261107.md`. The latter's held protected
Wire/SQLite proposals #56/#60 remain held; a feature/release request is not an
explicit replacement protocol/schema contract. No old branch deleted or closed.

## Blocking evidence and package mismatch

1. Current Veilopoly fails
   `MalformedTurnReferenceTests.testMalformedTradePartiesAndTiles:21`.
   Prior W1-006 receipt reproduced the SAME failure from clean fb245c3 archive.
   This is not a new UI failure, but is still a required whole-package gate.
   Affected Engine source/test must be reviewed; do not weaken the assertion to
   obtain a misleading green label. V5 has additional unexecuted risk/stress gates.
2. PR #180 remains DRAFT/unstable; latest native run42397878336 and standard
   run42397883246 are pending/in progress at intake. #6 comment6710898196
   explicitly records Chinese output FAIL and requests no main promotion yet.
   A unit test of the warning detector is NOT proof the model speaks Chinese.
3. Existing Core release workflow generates only `project.yml`.
   PR #180 explicitly excludes GGUF/native module from that normal project;
   its `scripts/make-vertex35m-project.py` adds bundled model and the embedded
   pinned llama framework to a separate generated build plan. Merging source
   then running the normal Core workflow alone would NOT fulfill Owner's
   requirement that the real model be present in the IPA. Need one verified
   combined carrier/build plan and model-byte/hash/architecture checks.
4. #178/#179 are alternative controller/UI implementations, not cumulative
   independent features. Review their different preference APIs and tactical
   gates rather than resolving by arbitrary last-writer-wins file replacement.

## Status / next gated action

`INTAKE_RECORDED / RELEASE_BLOCKED`, not APPLIED, MERGED, IPA_BUILT or RELEASED.
Only this audit record is committed on the preparation branch. Main/product
version/build, all feature/source branches and all workflows are unchanged.
No PR opened, workflow dispatched, tag/release created, IPA built or published.

Next: settle scope for the model's failed/unproven Chinese capability and obtain
an authorized concrete reconciled batch. Preserve safe defaults and resolve
actual test/build conflicts on a NEW integration candidate, then run exact-head
Apple full tests plus actual model carrier verification. Set29.0/new build only
for a validated candidate; normal guarded merge and unsigned IPA verification
must precede release. Signed distribution is not promised without valid signing.
Do not call existing experimental Vertex test IPA a V29 combined IPA.

Supplemental skill epoch/dual-learning/session machinery remains absent in the
actual V1.1 repo; PARTIAL/UNAVAILABLE, not a fabricated machine gate PASS.
Governance skill caused exact-head intake, duplicate/protected-surface review
and the release HOLD above, not a claim of testing an Apple SDK on Linux.

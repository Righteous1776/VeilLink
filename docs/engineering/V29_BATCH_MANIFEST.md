# V29 controlled batch

Task VEILLINK-V29-INTEGRATION-20261107, direct Owner authorization.
Base/rollback main2c5b5161027edff097b27fe3323d30f6ca3e430e; intake364601d.
Branch integration/v29-unified-20261107; no source branch rewriting.

Owner confirmed “确定” to including LingCore as explicitly EXPERIMENTAL with
Chinese capability unvalidated; compile/tests/IPA content gates remain mandatory.
No Chinese competence claim, tool/board/DB/communication authority for that model.

## Ordered inputs / reconciliation decisions

1. dev/veilopoly afa560718c2f8ac1bde0b73dcdc44a8451782c93: preserve latest UI,
   live host integration, fixed board, prior saves and all art.
2. dev/veilopoly-manual-v5-20261108 1f6532697e10abdb91f68ee4c30fbcd3b76a3183:
   add latest V5 economy/risk/manual ancestry. Known overlapping CHECKPOINT,
   UI and CityLongEconomy are reconciled explicitly, NOT last-writer-wins.
   Keep current V4 credit-crunch damping (V5 branch contains an older V4
   implementation); use versioned V5 logic only for new V5 games. Retain new UI
   and dynamic helper values rather than reverting to old money constants.
3. Board #178 c40613d88f7ae0350954f1c881d46014f0aaa216: CI-green complete
   R3–R8 stack, compact UI + optional full search on all devices. #166 is an
   absorbed precursor. #179 is an ALTERNATIVE of the same settings UI/API,
   not a second feature: preserve its branch, use the reviewed green #178
   API/default; do not replace it with a competing persistence key.
4. LingCore #180 cdd9faeaa58533be786acaa00bd89179157a7a60: actual pinned
   model/native runtime, text-only isolation and explicit experimental warning.
   Preserve model hash/license. #176 precursor not applied twice.
5. Inbox #165 451b8df08d86b418d8122e8b6fc152362909c6e2: reviewed import/hash
   cancellation patch and regression, apply product hunks once, not just merge
   inert proposal metadata. Existing V28 86-head ledger remains disposition
   authority for older Inbox content; no old snapshot/duplicate rollback.

Protected Wire/identity/SQLite/A9/A10/A13 policies stay unchanged; #56/#60 remain
held. No unrelated agent PR closed. Workflow/project/carrier changes are limited
to the Owner-requested combined V29 model build, verification and release path;
no credential/signing mutation or skip of tests. Retain existing size caps.

## Gates before main / release

Resolve actual integration errors without weaker assertions; full Linux SwiftPM;
source/protected/resource review; exact-head Apple simulator + ALL XCTest + device
Release build; actual GGUF size/hash/single-copy, llama architecture/embedding and
Veilopoly bundle/manuscript app–IPA parity; existing A10 shadow/hash constraints,
version/build/size checks. Model must be in the actual combined artifact, not
just source. Candidate29.0/new build only once local source gates pass. Normal
reviewable PR promotion, then immutable unsigned release. Physical RF/touch/
quality tests remain NOT_RUN unless really performed. No false device claims.

State: batch plan recorded; application and verification receipts follow in Git
and V29 integration log. This document alone is NOT main merge or publication.

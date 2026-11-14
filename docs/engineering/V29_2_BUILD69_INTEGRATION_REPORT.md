# [INTEGRATION-GOVERNOR] Build68 scope incident → V29.2 Build69 corrective branch

Base main: `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.
Backported focused performance head: PR #243 at `e4dbda4327a5226b46c52679eb001b81f49fa3d4`.
Working branch: `integration/20261115-v29_2-build69-incident-repair`.

## Decision ledger

| Capability | Build69 disposition | Proof limit |
|---|---|---|
| Build68 ten source-gated functional areas | Preserved | Existing successful Build68 main CI and IPA receipts; device acceptance open |
| iPhone 13 image-worker cancellation, runtime profile | Backported from #243 | New exact-head CI required, device stress unverified |
| ECLIPSE measured instrument cadence and throughput | Implemented | Metric derives from completed search only; no live fake progress |
| Full ECLIPSE R17.2 cockpit #234 | Deferred | Based on incompatible R16 hybrid; no main-safe semantic rebase or Xcode QA |
| VeilScreen R1 #232 + R2.1 #236 | Quarantined | Candidate only. No signed app group, typed E2EE media integration or dual-device proof |
| Gomoku #221 competition harness | Deferred | Non-product validation harness; zero 2,500-pair evidence |

## Incident cause and non-recurrence

A green source receipt for a chosen ten-area batch was interpreted as proof that all historic Inbox proposals had shipped. Future release announcements must enumerate both accepted and explicitly excluded candidates, inspect the compiled IPA receipt, and never relabel a proposal-only or partially implemented feature as operational.

## CI budget

1. Existing Build68 main CI + release is accepted evidence for unchanged code; never rerun it.
2. PR #243 already has an in-progress pipeline. Reuse its results for identical performance code; do not manually trigger duplicate runs.
3. The final Build69 exact source has new build identity and instrument changes; once an integration PR exists, ONE automatically triggered candidate CI is justified. Do not manually dispatch reruns.
4. Only an exact-head successful candidate may be merged, followed by the existing main publishing CI required by the repository's immutable release policy.
5. No early/synthetic 'green' declaration and no release-tag overwrite. If the CI fails, keep the PR draft and do not push main.

## Dependency and rollback

Build69 consumes PR #243 source changes but **does not authorize merging #243 separately**; doing so again creates duplicate/conflicting work. A future V29.3 plan should rebase from the eventual Build69 main if released. Build68 remains the last-known-good immutable rollback tag until then.

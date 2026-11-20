# [INTEGRATION-GOVERNOR] VeilLink V30 — Full-Inbox incident recovery register

Snapshot: 2026-11-20 · main `0e4b51e` · latest official release `v29.2-b68`.
Staged owner work: Build69 source `9a2a91b` and FORGE Soft R2 `d59e2c4`.

## Why three deliveries failed acceptance
GitHub Actions successfully compiled *selected* source trees, while open Inbox-only
proposals were incorrectly interpreted as integrated application code. A successful
workflow does not pull missing features into its checkout. This produced IPA artifacts
that did not contain several high-priority user functions.

## Full metadata inventory
All **234 retrieved PR records** including **153 open**, **151 open drafts** and **66 merged** are recorded
in `V30_REVIEW_LEDGER.json` with their exact head SHA and review disposition.
This is exhaustive **metadata enumeration**, not exhaustive semantic review. PRs
marked `needs_semantic_source_review` explicitly remain awaiting diff/content
inspection; do not call them accepted or delivered.

The current main tree contains 335 app Swift files and 36 Inbox submission groups,
but the newest VeilScreen R1/R2.1 and R17.2 proposals reside on other open PRs.
An Inbox file—even if present in main—is not an app target.

## Actual integration evidence
- PR #241 Wave3 Blackbox R5 head `5bdebf30f` is an **ancestor of main**:
  the open PR is stale, not evidence of an omitted R5 feature.
- PR #240 Wave2 FORGE is diverged by only a one-line AppTheme delta;
  its main features are inherited and the user now requests the separate Soft R2 style.
- PR #243 head `9a2a91b` passed exact-head CI **but has not merged to main**.
- VeilScreen PRs #232/#236 only modify `AGENT_INBOX/submissions/**`, and
  current product lacks the ScreenShare target, authenticated wire kinds,
  chat invite and ReplayKit upload extension.
- R17.2 PR #234 is also Inbox-only and conflicts with the owner's removal of
  decorative measured cards and move ripple. Accept select real search controls;
  do **not** import its UI in bulk.
- The 2,500-pair R8/R14 arena PR #221 is not evidence that any tournament
  was completed. No unsupported Elo/performance claims.

## V30 release blockers (mandatory)
1. **VeilScreen**: iOS ReplayKit Upload extension with real Apple signing/App Group
   and keychain; current authenticated BLE + dedicated E2EE domain-separated control
   and media; explicit sender and viewer consent; visible Chat '+' invite; bounded
   low-priority transport; no stored frames/chat leakage; stop/expiry/replay cleanup;
   sender/receiver signed hardware proof. NEVER show a fake enabled invite.
2. **ECLIPSE**: preserve upper robot, remove lower measured card and ripple; real
   slider/uncapped wall-clock option subject to cancel/node/depth guard; review
   R17 proposal for noncosmetic actual improvements with conflicting UI omitted.
3. **FORGE**: use exact Instrument light/dark background and robot warm orange;
   actual card/rotor render acceptance, no gestures intercepting chat scrolling.
4. **Regression**: Blackbox R5 privacy redaction; BLE/Game liveness; chat keyboard
   geometry, local bubble order; extreme image handling; file import lifecycle;
   existing game entrypoints and durable user archives.
5. **Release provenance**: version 30.0, monotonic build 70, exact-head compiled
   iOS simulator/XCTest and iPhoneOS release, verified app extension in IPA,
   manifest hash, two actual signed devices. No original release tag reuse.

## Local vs Apple-only testing
A Python-only fail-closed source/IPA inventory gate lives in
`scripts/v30_source_gate.py`. It is *not* Swift type checking, XcodeGen,
iOS framework compilation, signing or BLE real-device tests.
Current gate is intentionally **RED** until the missing production integrations
and physical receipts exist. Run one consolidated candidate GitHub Actions job
only after preflight evidence is ready. Never promote the R0 legacy protocol,
overwrite main, or advertise V30 as already shipped.

## Integration governor decision
This is an **audit/integration branch**, not `main` and not a V30 release.
PR inventory may be fully indexed while semantic decisions are incomplete.
V30 must not be tagged or called complete until release gate becomes PASS
with verified product/compiled and two-phone acceptance evidence.

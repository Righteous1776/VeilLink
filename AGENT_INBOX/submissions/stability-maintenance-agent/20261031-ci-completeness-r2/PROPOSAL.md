# Proposal — CI completeness R2

## Scope — what is actually patched
Seven repository paths, based on exact main `403b3dc474746d3925ad52fa4169225905bac7fc`, staged only as `PATCH.diff`.

1. `scripts/ci-test.sh` selects a stable, newer available iPhone simulator deterministically, allows fail-closed exact runtime request (`VEILLINK_SIMULATOR_RUNTIME`), and stores selected runtime + explicit `physical_device_verified=false` in JSON. It **does not pretend iOS15 hardware is tested**.
2. `scripts/ci-collect-evidence.py` extracts XCTest pass/failure/missing evidence, failing case identities, suite count, and simulator metadata; `--require-tests-passed` fails closed if unit/UI test evidence is absent even if shell runner misleadingly exits zero.
3. Adds four pure Python tests of the parser and runs them in `ci-standard-preflight.py`.
4. `project.yml` includes an XCUITest smoke-test target. The first-launch `VeilLinkUITests/PreConsentSmokeUITests.swift` checks that the unsigned, before-signature blackbox export button is present **and hittable**, no profile creation or auto-permission. iOS15 behavior must be checked on real iPhone7 separately.
5. `ios-ci.yml` integrates the test summary gate, records XcodeGen version, and adds Release-configuration `iphoneos` **compile-only** parity check on PRs without packaging an IPA or publishing a GitHub Release; expands per-job timeout to 50m for additional compilation.
6. Pins ZIPFoundation to **0.9.20**, matching the actual successful 2026-10-30 PR #100 resolver output. This avoids silently updating backup/ZIP behavior on new CI runs.

## Existing fixes that must be integrated once (NOT duplicated in this patch)
- Draft #104 fixes stale default-mode Gomoku test expectation in PR #96/#99; no reason to reapply as second independent implementation.
- Draft #105 makes release publication opt-in. Review protected release path independently and consider additional Github Environment/Owner approval.
- Other product P0 branches #64/#65/#66 (touch/consent), #97 (BLE), #103 (LAN/relay), #92/#93/#94/#95 (Files/migration) and #100 (Monogatari) must be explicitly arbitrated, not auto-merged all together.

## Limits and critical gaps remaining
- macos-15/Xcode16.4 runner cannot be assumed to have an iOS15 runtime. Selecting newest runtime is a **documented general smoke test**, not an iPhone7 certificate.
- There is no device-farm connector or user iPhone7 attached. iPhone7 touch, Keychain, local-only WKWebView policy, provider URL scopes and data/backup restore remain pending.
- New XCUITest target is a real source candidate but Apple build and runtime have NOT been run in this lane. Governor must run exact-head iOS CI to identify Swift/XcodeGen incompatibility and refine.
- UI smoke checks the export button as a visible, hittable control; it does not test actual Files share completion nor guarantee every consent control works.
- Swift6 concurrency warnings are kept visible; blanket `@preconcurrency`/unchecked sendability would not demonstrate correctness.
- XcodeGen is version-recorded, not fully pinned. For reproducibility, Governor should select a checksum-verified pinned installer before rollout.

## Acceptance criteria
Exact-main patch replay; Python evidence parser local 4/4; XcodeGen generation of UI bundle; iOS Debug simulator + XCUITest and full XCTest; unsigned Release iPhoneOS compile; complete evidence; signed-device matrix and governor arbitration. **No release, version bump, IPA, or main changes from this lane.**

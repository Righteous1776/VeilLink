# Test Plan — CI completeness

## Local source checks
- Replay full-file hunks against exactly `403b3dc474746d3925ad52fa4169225905bac7fc`; `git apply --check PATCH.diff` plus check diff restricted to seven paths.
- Run `python3 -m unittest discover -s scripts/tests -p 'test_ci_*.py' -v` — four parser tests, including prior real-world 789/1 failure.
- Run `bash -n scripts/ci-test.sh`; Python compile and preflight syntax checks.
- `xcodegen generate` with ZIPFoundation 0.9.20 and `VeilLinkUITests`; inspect new target's test host and bundle entitlement.

## CI on exact Governor integration head
- `ios-ci.yml` static preflight and XcodeGen generation.
- Run 785+/789+ unit tests + new UI smoke; require structured `tests.status=passed` and report simulator runtime.
- Compile Release `iphoneos` with `CODE_SIGNING_ALLOWED=NO`, not a new IPA or release.
- Confirm `CI_EVIDENCE.json` includes test names and simulator metadata.

## Negative tests
- Empty XCTest log: must not pass summary gate.
- Prior test log with Gomoku assertion failure: fails summary gate and includes failed identity.
- Required missing simulator runtime: fail, never silently run on another OS.
- Signing gate not satisfied: preconsent blackbox button still present and tappable.
- UI test must not initialize AppModel, database, BLE, LAN or Relay before required consent.

## Matrix/OS
- CI selected iPhone runtime: version recorded; not iOS 15 certificate.
- Owner device: iPhone7/iOS15.8.3, new iPhone iOS26, signed and unsigned installation behaviors, IME first consent, dark/light force restart, scroll/sliders, provider cancel/restore, BLE/LAN/relay two-device transitions.
- Monogatari WKNavigationDelegate policy behavior under iOS15 WKWebView, tested on selected candidate #100 after separate runtime patch review.

## Regression invariants
No protocol/schema changes, no auto publication, no credential logging, no writes to original encrypted backup.

# Test Plan — protected release gate

## Static checks
- `git apply --check PATCH.diff` on exactly `403b3dc474746d3925ad52fa4169225905bac7fc` in a Governor integration branch.
- `actionlint .github/workflows/core-release.yml` and YAML parser.
- Confirm `unsigned-ipa.yml`, `dual-platform-release.yml`, `local-ai-heavy-validation.yml` and `malecns-heavy-validation.yml` callers are unaffected except for explicitly gated publication.
- Confirm full diff only touches release control and never changes built product/version/signing/protocol.

## Publication decision matrix (Governor-controlled dry-run)
| Trigger | ref | publish_release | Expected public Release |
| --- | --- | --- | --- |
| main push to project.yml | main | absent/false | NO |
| workflow_dispatch | main | false | NO |
| workflow_dispatch | main | true | ELIGIBLE only after preflight/package + Owner approval |
| workflow_dispatch | integration branch | true | NO |
| wrapper workflow_call without input | main | default false | NO |
| wrapper workflow_call explicit true | main | true | ELIGIBLE if authorized; audit caller before allowing |

Do NOT launch release/IPA workflows from this Agent. Governor should test syntax, use non-public dry-run controls or policy review, and require Owner approval before a real publication.

## CI coverage follow-up
- Pin explicit runtime and emit simulator runtime metadata in `ci-test.sh`.
- Add iOS15-targeted simulator when available, and real iPhone7 iOS15.8.3 physical gate.
- Add UI tests for first-sign Chinese IME input, scroll/slider hit-testing, light/dark relaunch, pre-consent blackbox export.
- Run BLE loss/reconnect on two devices, including LAN/relay transitions and background/foreground.
- Add WKNavigationDelegate allowlist runtime test for external URLs in #100.
- Add Swift6-concurrency warning inventory and a tracked zero-warning migration plan.
- Parse `xcresult` failure count and failing test identities into CI_EVIDENCE and check count consistency.

## Exit conditions
No public release or direct product modification in this submission. Exact-head CI and physical device sign-off are separate Governor/Owner gates.

# V27.0 integration and release gate

## Owner request

Merge the applicable Inbox contents as a major `27.0` release and publish an IPA.

## Current authorization state

The repository is in `INBOX_ONLY`. `AGENTS.md` reserves cross-lane merge order, version/build values, workflow dispatch, IPA/signing and release publication. A valid integration window must contain:

`[INTEGRATION-GOVERNOR][LIVE-LANE-GRANT]`

and name the integration branch, allowed files/subsystems, prohibited surfaces, expiration and required validation. No such current grant was found in Issue #6 at the time of this submission.

## Proposed V27 waves

1. Freeze current `main` and all eligible Inbox heads; record exact SHAs.
2. Integrate and verify P0 #64–#66 first, with physical iPhone 7 consent/text/gesture/data-continuity evidence.
3. Add the feature registry foundation and one integration-owned Feature Library route.
4. Import source-complete low-risk tools; explicitly reject catalog-only rows and choose one implementation from duplicate proposals.
5. Integrate games/entertainment by canonical generation, never by stacking V1/V2/V3/R6/R7 over the same paths.
6. Reconcile `project.yml`, `Info.plist`, Tool Center and license notices once.
7. Run static preflight, XcodeGen, simulator build, complete XCTest, dependency/license audit and protected-surface diff review.
8. Run physical iPhone 7 tests for first-sign consent, input, dark/light UI, BLE/LAN, games, thermal and storage continuity.
9. Only after green gates: set the Governor-approved 27.0 version/build, merge to main, invoke the established unsigned IPA workflow, verify SHA-256 and publish immutable release notes.

## Stop conditions

- Missing source or license provenance.
- Patch overlap resolved by deletion/overwrite rather than review.
- Keychain/SQLite/protocol continuity regression.
- Consent input or touch failure on iOS 15.
- Apple build/XCTest failure.
- Release artifact SHA mismatch or workflow/signing drift.

# VeilLink 26.13 · Build 59

Build 59 is the cumulative UI and maintainability iteration on top of 26.12 Build 58. It preserves the existing iOS 15 baseline, Protocol 4, VLGM1 v1, SQLite Schema V8, identity/key contracts, BLE/LAN transport contracts, and A9/A10 shadow governance.

## Highlights

- Adds a shared 4pt-based `VeilSpacing` token layer and terminal/card title typography tokens, migrating repeated values across conversation, game lobby, settings, mini-games and Tool Center.
- Makes the legal-consent acknowledgment input IME-aware so uncommitted composition text is not published to the signing state. The primary sign action remains reachable when all three explicit confirmations are complete and validates the acknowledgment when invoked.
- Adds the authorization-gated experimental “白描 / Plainline” minimal typography theme and the selectable “浮屿 / Islet” deep-sea floating-island theme while retaining all existing appearance themes.
- Updates `scripts/local-ci-sim.sh` to reflect current version inheritance, release-workflow delegation, game navigation, current unit-test expectations and A10 shadow contracts.
- Fixes the Agent Inbox submission manifests for the two appearance proposals so the required `base_main_sha` is present and the machine gate passes.

## Validation gates

The release remains publishable only if static preflight, audited asset provenance, XcodeGen generation, iOS Simulator build, the XCTest inventory, unsigned iPhoneOS Release build, Core source-isolation, size/resource budgets, release manifest/provenance generation, and SHA-256 verification all pass in GitHub Actions.

## Compatibility and release notes

- Marketing version: **26.13**
- Build number: **59**
- Minimum app deployment target remains iOS 15.
- The Core IPA is unsigned and requires appropriate Apple signing/provisioning before normal-device installation.
- Simulator/XCTest results do not replace physical-device IME, touch/navigation discovery, BLE/LAN radio, backgrounding, thermal, or battery validation.

# VeilLink 26.13 · Build 59

Build 59 integrates the governed Kimi local-iteration batch on top of VeilLink 26.12 / Build 58.

## Highlights

- Adds shared 4pt-based `VeilSpacing` tokens and a reusable `VeilType.terminalLabel` token across chat, games, settings, tools and status surfaces.
- Normalizes gold-accented card and section headings through the `VeilType.cardTitle` role.
- Prevents uncommitted Chinese IME composition text from contaminating legal acknowledgement state; keeps the sign action reachable after the required confirmation boxes and validates committed acknowledgement text on submission.
- Adds the optional experimental **白描 (Plainline)** appearance, with a typography-and-hairline navigation frame, gated through the existing app-lock PIN.
- Adds the optional **浮屿 (Islet)** appearance, with an aurora-inspired background, floating content surfaces and a collapsible compass navigation capsule.
- Brings the Linux local CI simulator into alignment with the current workflow graph, version inheritance, game navigation, replay invariants and A10/MaleCNS shadow constraints.

## Compatibility and protected surfaces

- Minimum iOS deployment target remains iOS 15 for the main app.
- Protocol 4, VLGM1 v1, SQLite Schema V8, identity/key contracts, transport contracts and release/signing boundaries are unchanged.
- Experimental appearance styles are opt-in; the three existing appearance choices remain in the normal theme picker.
- The Core IPA is unsigned. Normal-device installation still requires appropriate Apple signing and provisioning.

## Validation

The authoritative result is the GitHub Actions run for the exact release commit. Release publication is blocked unless static preflight, XcodeGen generation, iOS Simulator build, XCTest, unsigned iPhoneOS Release build, Core source-isolation and size/resource checks, release manifest/provenance generation and SHA-256 verification all succeed. See the corresponding Actions run evidence and release assets for the actual result.

Physical-device rendering, Chinese IME first-tap behavior, floating navigation discoverability, and BLE/LAN, thermal and background behavior still require owner/device validation.

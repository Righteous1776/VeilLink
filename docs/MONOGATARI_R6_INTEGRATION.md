# VeilLink × Monogatari R6 — Controlled product-branch integration

## Ownership / scope
- Integration Governor candidate, independent branch only. Owner requested "优化后入库" / "接着断点继续".
- Target original baseline: `403b3dc474746d3925ad52fa4169225905bac7fc` (27.0 Build62).
- Goal: add a real offline visual novel to GameLobby rather than a missing-resource placeholder.
- No `main` merge, no version/build/signing edits, no IPA/release workflow dispatch, no BLE/SQLite/Keychain mutations.

## Upstream and source provenance
- Official [Monogatari v2.8.0](https://github.com/Monogatari/Monogatari/releases/tag/v2.8.0), MIT copyright Diana Islas Ocampo.
- Owner supplied genuine official ZIP, 2,798,775 bytes, sha256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`; R5 full local ZIP `068ba55bfa36672d61960240a684dc4d90ceb7a10868409baf73bc4e6ac6c6f1`.
- **55/56 upstream files** reconstructed from original release Git tag `v2.8.0`, with exact Git blob SHA verified on upload into this repo.
- Intentionally NOT bundled in iOS candidate: optional `engine/core/monogatari.js.map`, 5,429,122 bytes of *debugging source map only*, upload repeatedly blocked by HTTP/2 transport. The real runtime JS `engine/core/monogatari.js` (2,675,936 bytes) is byte-identical to upstream Git blob `0211c2f2c9adc56e28d5583feb0dd46b902d37d5`.
- `engine/` upstream runtime remains unchanged; `index.html`, `js/options.js`, `js/main.js`, `js/script.js`, new `js/veillink-native.js` and CSS are legitimate game-level overlays only.
- Full source archive with all 56 originals is kept in the owner's R5 offline package; absence of source map in iOS product bundle is disclosed, not represented as all 56 upstream files in Git.

## Product integration in this branch
1. New `VeilLink/Resources/VisualNovelBundle/` offline game bundle: real browser engine, origin-sandboxed local assets, MIT notice, startup bridge, iOS15 compatibility shim, Chinese original story 19 labels / 3 choice nodes / 4 outcomes.
2. Three Swift files under `VeilLink/Narrative/`: `WKWebView` SwiftUI container + manual recovery, read-only bounded custom scheme resource handler (single-range/256 KiB streaming), pure Foundation byte range validation.
3. New true game navigation row in `GameLobbyView.swift`, not a disabled or placeholder entry.
4. `project.yml` resources exclusion + explicit folder reference to preserve nested `VisualNovelBundle/engine/` hierarchy.
5. `VeilMonogatariRangeTests.swift` 3 independent XCTest methods / 15+ parser assertions.

## Local evidence and known limits
- Original R5 package: 5 Node suites, 5 Python suites and 15 Swift Foundation range fixtures passed on Linux; Swift frontend parse passed on original R5 sources.
- New R6 inline host structure and GameLobby/project.yml diff are **new and not Apple SDK typechecked yet**.
- Need verify XcodeGen folder reference placement in generated .pbxproj, `.app/VisualNovelBundle/engine/core/monogatari.js`, full Apple SDK CI/XCTest on exact commit.
- No actual iPhone7 iOS15.8.3 boot, save-after-force-quit or touch/gesture tests. Code must not be represented as proven playable.
- Note: `loadFileURL` and custom-scheme origins can carry distinct WebKit storage namespaces. No silent migration/clearing.

## Overlap / stop
- Existing Draft PR #92/#93 propose GameLobby changes; Governor must reconcile, not overwrite. Draft integration PR #96 is unrelated 8-point upgrade and its CI HOLD must not be bypassed.
- P0 old-device onboarding/signing/gesture (#64,#65,#66) remains guarded. Owner explicit approval is still needed to release a new IPA.

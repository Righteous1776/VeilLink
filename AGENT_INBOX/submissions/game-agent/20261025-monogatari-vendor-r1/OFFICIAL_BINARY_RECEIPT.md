# OFFICIAL UPSTREAM BYTE RECEIPT — 2026-10-25

## Previously blocking download is now resolved
The repository owner uploaded the *actual* official release file `monogatari-v2.8.0.zip` into the current ChatGPT workspace. Its SHA-256 matches the pinned GitHub Release:
- raw archive bytes: **2,798,775**
- raw ZIP SHA-256: `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`
- archive entries (including folders): **75**
- regular file entries extracted: **56**
- unpacked official bytes: **9,791,155**
- `engine/` blobs compared **byte-for-byte: 12/12 PASS**
- core `monogatari.js`: **2,675,936 bytes**
- unchanged upstream manifest SHA-256: `6fc4b34e251d30561e5497214418003db40d0815c453efecfd4106284ac0c50a`
- official release source: https://github.com/Monogatari/Monogatari/releases/tag/v2.8.0

## Full binary-containing offline deliverable
`VeilLink_Monogatari_OfficialFullEngine_R2_20261025.zip`
- package ZIP bytes: **5,663,449**
- package SHA-256: `21e69c88d541d7cf61eae3e1c9cc6142f11b33a54718d7d0897471761f182401`
- source: user-facing ChatGPT conversation artifact, **not uploaded into GitHub Inbox**
- includes original official ZIP untouched; extracted real `VisualNovelBundle`; 2 SwiftUI/WebKit source files; vendor tooling; add-only gated local integration helper; license and provenance.

## Verification performed
- Official ZIP SHA-256+size: PASS (real bytes)
- Verbatim upstream `engine/` tree SHA-256 compare: 12/12 PASS
- Reproducible real engine unpack + story overlay + repeated import: PASS
- Node.js `--check` vendor browser JS and overlay: PASS
- Story state graph: 19 nodes, 3 choices, 4 endings, 36 reachable states: PASS
- Swift parser on two iOS host Swift files: PASS **syntax only**
- Local mock checkout: integration dry-run + add-only apply + reapply refusal: PASS
- Package CRC and embedded SHA256SUMS: PASS
- Chromium browser smoke attempted: **BLOCKED_BY_ADMINISTRATOR** for file: and localhost URLs; no runtime success claim.

## Truth boundary
**Real official binary import into the offline integration package: COMPLETE.**
**Binary import into VeilLink GitHub product tree and a runnable IPA: NOT DONE.**
This pull request contains text-only provenance and the independent vendor verifier, not the upstream release binaries. The Governor must import the exact R2 package on a separate integration branch, verify resources are copied into .app by XcodeGen, build/XCTest with Apple SDK, and test physical iPhone7 iOS15.8.3. No main merge or IPA Action was dispatched.

# ECLIPSE R10 verification
## Executed
- Swift 6.2.1 Linux, strict swift-version6/warnings-as-errors/-O compilation, PASS.
- ECLIPSE strategy 59 deterministic checks PASS: immediate win, unique mandatory block, legal-root containment, forced double-win whitelist, opponent reply bait counter, bad position and budget fallback, 16 symmetries, 32 seeded midgame legal moves (7264 examined search nodes).
- Compute contract 18 budget asserts PASS: 1/2/4/6x total invariant, sum of optional stage budgets equals total, deadline math, invalid parameters rejected. Owner ZIP includes replayable `FILES/TESTS` sources.
- Package integrity: complete source and diff are in SHA256-pinned owner ZIP; no binaries or neural weights.

## Required before integration
1. Apply separate owner ZIP full source patch onto review branch pinned to `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`; validate product-tree scope.
2. Compile real R5/native bridge, V9 seven-tier policy, R9 no-hints UI, with Swift 6 Xcode and all XCTest; verify iOS15/26 supported targets as actually applicable.
3. Exhaust opponent immediate wins and R4 fork escapes; prove no illegal move, no beam-pruned forced block, no stale-ticket result and no PV exposure.
4. 5000+ completed equal-time matched-opening color-swapped games against frozen V29/R5/V9; report tactical solve and confidence bounds separately from time multipliers, avoid counting unfinished as draws.
5. Thermal, memory, battery, app-background/cancellation and SwiftUI instrumentation on iPhone13 + iPad. Run no workflow/IPA until Governor approval.

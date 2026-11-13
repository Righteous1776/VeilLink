# V10 test plan

Completed locally:
- Swift 6.2.1 `-swift-version 5 -warnings-as-errors -O` + `-swift-version 6 -warnings-as-errors -O` both compile and execute.
- 48 deterministic assertions over 8 rotations/mirrors, both stone colors, immediate defender winning counterexamples, ordinary single-threes, node and time expiration.
- 3,448 independent oracle-verified defender branches: 8 x 216 black plus 8 x 215 white.
- 120 randomized legal 14-ply states tested: zero V10 proof certificates, therefore random set adds no empirical precision estimate for successful proof cases.
- `PATCH.diff` from owner ZIP checked/applied to an isolated empty tree with two new files, not a full source checkout.
- XCTest source only parsed, NOT executed in an Apple host.

NOT_RUN: full product Xcode compile, XCTest, actual main git apply check, original 212 private fork fixture replay, matched long tournaments, iPhone/iPad thermal and battery.
Mandatory Governor check after PR #199 integrated: cap work/time, test fallback on incomplete searches, prevent leak of coordinates into ECLIPSE UI.

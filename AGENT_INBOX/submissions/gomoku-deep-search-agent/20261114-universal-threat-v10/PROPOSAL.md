# V10 companion module for V9, not a replacement

Verified baseline: main eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0 currently has native R4 defensive fork gate, R6 trained ranking, R8 immediate double-win proof, and optional JSCore search. Draft #199 proposes V9 seven strength-budget tiers (2/4/6× compute budget, not measured winrate) and unique forced-block forcing-four search. No V9 product merge detected.

V10 adds an original Foundation-only Swift `GomokuUniversalThreatV10` checker that handles a restricted three-attacker-move VCT case: root move R produces no immediate fifth-stone completion; enumerate ALL legal opponent replies D; require for each D a legal follow-up attacker move A creating TWO distinct immediate-five finishing squares, without an earlier defender immediate win. Only after exhaustive branch validation return a certificate. Cancellation, deadline and node-cap exhaustion return nil (unknown) and never a fabricated victory.

Optimization: a defender stone cannot create a new attacker-only 4+1 window, so all possible fork-producing attacker second moves are precomputed on the root board and then revalidated for EVERY defender response. The geometric fork predicate is the existing native GomokuCounterForkR4 API; an independent brute-force move sequence oracle rechecks outcomes without calling R4.

Local owner ZIP contains **full 170-line Swift implementation**, **105-line XCTest**, runnable Linux stand-in, independent oracle, `PATCH.diff` adding both files (no product file overwritten), trace logs and a proposed post-V9 optional hook. The Github proposal deliberately does NOT claim that downloadable local ZIP has been pushed as a product code change.

Integration Governor sequence: adjudicate PR #199 first, stage two additive sources from owner ZIP in a dedicated integration branch, run full Xcode XCTest then only if green consider adding optional V10 bounded proof slice after mandatory five/R8 gates and before V9 search. Do not touch scoring, training databases, UI themes or model weights. V10 isn't general VCT or 6× chess skill proof.

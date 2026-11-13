# ECLIPSE R11: Real tactical upgrade, not merely time scaling

## Finding
On a fixed legal freestyle 15×15 tactical position, R10's very short node-budget fallback can rank tempting roots ahead of the one root avoiding an opponent's *next move* fork. The fork is a rules-verifiable threat consisting of two DISTINCT immediate five-completion squares. In a controlled one-node replay, favoring each of 3 dangerous roots causes R10 to select them; R11 catches the opponent's exact counter and removes only those roots if a safer legal vetted choice exists.

## Executable work
- New pure Swift `VeilEclipseTacticalOracleR11.audit`: entire incumbent vetted root set, immediate own five / opponent five, own independently provable double-five, opponent next-turn double-five fork, precise short-loss root filtering, complete-work/time cap or fail-closed nil.
- New `VeilEclipseR11DecisionBridge`: `.shadow` is decision-neutral; enforcement requires integration approval, consumes at most 35% of the ALREADY allocated R10 search slice, and routes only remaining time to incumbent R10. It never adds another 2x/4x/6x budget.
- No opponent move is omitted by beam truncation in the fork audit. A predicted human reply is NOT treated as a guarantee or proof of intention.
- Only V9/R4/R6/R8-vetted roots may be supplied. R9 no-live-hints telemetry boundary remains intact; opponent counter, PV, and trap coordinates stay private.

## Verification
Swift 6.2.1 Linux strict optimized build and **209 assertions** PASS; 80 seeded nonterminal audit examples and 979,981 five-cell window checks, symmetry and invalid-cap cases. The frozen tactical micro-corpus comprises 1 constructed root position × 8 transformations × 3 bait preference assignments = 24 dependent decisions: R10 unsafe=24, R11-gated unsafe=0. This is NOT 24 independent chess games, human-level victory or Elo improvement.

## Integration
Wait for Governor to reconcile #193/#196, #199, #204, #207. First merge R10 exactly once from its reviewed source package, apply PATCH.diff on dedicated integration branch, run full iOS XCTest and real-device benchmark, and pass matched-opening equal-time arena before allowing the enforcement switch. Never merge a proposal PR as if it were product implementation.

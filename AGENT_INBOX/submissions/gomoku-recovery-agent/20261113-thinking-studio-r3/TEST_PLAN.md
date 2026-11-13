# Planned tests (NOT executed for product code)

1. Apply proposed diff with 'git apply --check' after syncing new main and reconciling PR #186; no main mutation until Governor accepts.
2. Verify R2 fork: input real board at game 72 / ply 12; historical 83 fails safe gate and 67/123 are recognized.
3. Own immediate five and opponent immediate five cases always override PVS/VCF candidate.
4. PVS/VCF branch does not bypass native learning/R4/R8 and does not silently compare different score scales.
5. Same-device, equal-turn-wall-time benchmark of native-only, old external-only, and candidate fusion; measure legal moves, wins/losses, thermal and battery.
6. True native telemetry invariants: emitted nodes never exceed actual visited nodes; candidate count reflects real roots; no fabricated JS depth or PV.
7. Async cancellation: restart, navigation, rapid turn switch, old-generation callbacks never update new view.
8. iOS VoiceOver, Reduce Motion, dark/light, Dynamic Type, iPhone 13 / iPad, status ribbon must not obscure board touch input.
9. Validate code under actual Apple Swift SDK, strict concurrency, regression XCTest, no IPA/signing workflows before gates.

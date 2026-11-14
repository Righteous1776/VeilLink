# R11 Test Plan

## Executed in source package (owner ZIP)
- Linux swiftc 6.2.1 with -swift-version 6 -warnings-as-errors -O: PASS.
- FILES/TESTS/main.swift: 209 strict assertions PASS, including immediate own win/opponent block, R8 double-five, 8 geometric symmetries, full legal-root containment, no false-win claim, exact opponent reply replay, zero-window and expired-clock fail-closed, default shadow parity, 80 fixed random nonterminal audits.
- FILES/TESTS/arena/main.swift: 24 dependent fixed tactical decisions: before audit 24 classified short tactical losses, after audited root filtering 0. Not independent games, not Elo.

## Product gates (NOT_RUN)
1. Pin main eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0; integrate exactly one verified R10/R5/V9 source and R11 add-file diff into dedicated integration branch.
2. Swift 6/Xcode iOS target compile and complete XCTest (native proposed tests in FILES/VeilLinkTests).
3. Defensive property fuzz: actual current GomokuState replay and every apparent fork proof verified independently; hard gate own-win, mandatory block, V9 proof and R4/R8 priorities remain unchanged.
4. Equal-time and matched-opening paired full games against frozen R10/V29 with side swaps, >=5,000 completed games, 95% confidence bounds; all unfinished games counted separately.
5. Device: iPhone13/iPad Air4 thermal/memory/battery, app cancellation/background and 7-tier settings/legacy restores; R9 live anti-hint UI.
6. Integration Governor reviews and signs acceptance before any promotion, release, IPA or version change.

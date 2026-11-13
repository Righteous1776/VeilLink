# V9 standalone deterministic Linux checks (2026-11-13)

Only the staged `FILES/GomokuForcingSearchV9.swift` is production-proposed code. The two source files in `FILES/STANDALONE/` provide a lightweight simulator with the same current 15×15 unrestricted five-in-a-row turn/win rules, not the actual app engine.

Reproduction from within the submission directory:

```sh
swiftc -O FILES/STANDALONE/Stub.swift FILES/GomokuForcingSearchV9.swift FILES/STANDALONE/main.swift -o /tmp/gomoku_v9_probe
/tmp/gomoku_v9_probe
```

Executed on Linux Swift 6.2.1: **34 checks passed**, wall time under 0.1s for the four 8-symmetry patterns and two cap checks (compile time excluded). Two positive synthetic forks, one negative where the defender can win immediately, one single-stone negative, and two expired/zero-budget negatives.

No full iOS application build, actual native XCTest, or comparable head-to-head games were executed. Baseline branch `agent/gomoku-v9-inbox-20261113`, source SHA pinned to `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`.

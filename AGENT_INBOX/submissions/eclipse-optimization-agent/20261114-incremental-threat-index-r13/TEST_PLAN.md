# R13 test and acceptance
Executed:
- Linux Swift 6.2.1 -O -swift-version 6 -warnings-as-errors compilation PASS.
- 14,691 property assertions on 850 deterministic placements/undos with independent naive board scan; 156 fork cases; every exact-winning completion square cross-checked; invalid input; final undo returns initial board.
- 575 independent synthetic quiet board inputs x 10 simulated black root moves = 5750 dynamic opponent fork scans and undos, baseline and indexed exact fork totals both 2045. Measured ~15.7–18.0x for this microbenchmark with optimized Swift, not whole match time.
- Native XCTest source staged for later Xcode execution (NOT_RUN).

Required:
1. Governor chooses Codex #209 fitted kernel; verify exact blob 950a43db5ce6ce0ceb9292c656c30f6e87dd9542 and frozen trained model f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe; apply its existing product patch into isolated integration branch.
2. Apply only R13 PATCH_AFTER_CODEX_PR209.diff against that preimage, incorporate exact source/XCTest. DO NOT apply the kernel patch directly to current V29 main.
3. Swift6 iOS full target compile, XCTest of native kernel and code paths with r13 flag off/on, copy-on-write/undo stress and SIMD/ARM64 memory.
4. Compare chosen moves, proven tactical outcomes and actual per-turn elapsed/energy between OFF/ON at SAME node/time caps (fresh games, side-swapped openings; 5k completed matches if strength claim desired). Any increase in illegal moves, tactical misses or time limit -> default remains off.
5. Integrate R12 #212 after resolving overlapping kernel path rather than overwriting either; measure peak resident memory/thermal on iPhone 13 and iPad Air4.
6. R9 #204 prohibits hint coordinates/PV during active play; never wire tactical index to live UI. Governor solely controls merge/version/IPA/release.

# Standalone verified R12 source

Source module: `FILES/EclipseHorizonQuiescenceR12.swift` (SHA256 13d32513deeb2602a05ceb98dff822396863676fd1d64a41267c6a024ef27969). Product XCTest source: `FILES/VeilLinkTests/EclipseHorizonR12Tests.swift` (SHA256 8d9f2ed26b270c40b8bd9c31144805a8573e9085c11dbd6301ee8bd293360d96).

GitHub staged `FILES/VeilGomokuUnifiedSearchR12.swift` is the **full Codex trained native kernel with opt-in R12 leaf hook**, not a copy of the 48-tree weights or any re-fitted model. Product advisory `PATCH.diff` includes its TWO source hunks and exact new helper and XCTest files. Verify preimage only against Codex #209 staged source blob 950a43db5ce6ce0ceb9292c656c30f6e87dd9542; it is NOT directly applicable to V29 main.

Local standalone proof (from same owner ZIP/folder): `swiftc -O -swift-version 6 -warnings-as-errors FILES/EclipseHorizonQuiescenceR12.swift TESTS/main.swift -o /tmp/ecl-r12 && /tmp/ecl-r12` prints `R12_HORIZON_PASS assertions=1607 real_codex_positions=3 transforms=32 random=500`.

No locally mounted Swift 48-tree full source for independent iOS compilation (GitHub version is available via PR #209); no Xcode/iOS test or competitive win-rate claim. Original Codex 920 games were read-only audited, not added to model fitting or database.

# Reproduction

Upstream trained kernel: PR #209 at `d93e579a1b01e66be77b8e2d45cf2c60cd58b1df`. Required new helper source is `FILES/EclipseHorizonQuiescenceR12.swift`. Full trained-kernel overlay is `FILES/Native/VeilGomokuUnifiedSearch_R12_Overlay.swift` and exact diff against frozen Codex source `FILES/Native/R12_KERNEL_OVERLAY.diff`. `PATCH.diff` has 3 sections and is **layered on Codex #209 product integration**, not main.

Download/extract the Owner delivery ZIP, run from its root:

```bash
swiftc -O -swift-version 6 -warnings-as-errors \
    FILES/EclipseHorizonQuiescenceR12.swift FILES/TESTS/main.swift \
    -o /tmp/eclipse_r12_probe
/tmp/eclipse_r12_probe
# R12_HORIZON_PASS assertions=1607 real_codex_positions=3 transforms=32 random=500

mkdir -p /tmp/eclipse_r12_bench_run
cp FILES/TESTS/Bench.swift /tmp/eclipse_r12_bench_run/main.swift
swiftc -O -swift-version 6 -warnings-as-errors \
    FILES/EclipseHorizonQuiescenceR12.swift /tmp/eclipse_r12_bench_run/main.swift \
    -o /tmp/eclipse_r12_bench
/tmp/eclipse_r12_bench
```

Full 192-case JSON tactical fixtures are in GitHub Inbox at `FILES/TESTS/codex_920_r12_cases.json`, with 48 per category and source game/pair/ply provenance. The recorded 192 parity checks used a separate contiguous-five reference over each reconstructed legal board. Product/iOS XCTest and training-vs-enhanced equal-time game matches remain NOT RUN.

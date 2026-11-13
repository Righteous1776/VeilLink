# Production GomokuBot integration check

`run_integration.py` compiles the complete proposed `Native/GomokuBot.swift`, its real bridge, ECLIPSE search kernel and fitted ordering, difficulty policy, plus the complete incumbent `GomokuCounterForkR4.swift`. It extracts the actual production Gomoku rules, difficulty enum, formation types, adaptive snapshot and Gomoku hash functions verbatim into a temporary support file. It substitutes no invented game or learning implementation. Extracted support, source hashes, compiler output and executables remain in an external work directory.

Run from the repository root:

```sh
python AGENT_INBOX/submissions/eclipse-training-agent/20261113-million-r10/FILES/IntegrationTests/run_integration.py \
  --repo /workspace/VeilLink \
  --work /workspace/scratch/eclipse-integration-final \
  --swiftc /workspace/scratch/swift/usr/bin/swiftc
```

The independent old-engine diagnostic with `rootCandidateLimit=1` identifies the exact incumbent ranked root. A direct bridge call uses that root, then the default real product hook must match its index, score and node count while differing from the old engine's score/nodes. If the product hook silently falls back to the old implementation, this test fails. The test repeats this for both colors and all four explicit difficulty requests. It also verifies legal moves, immediate win/block priorities, terminal/wrong-turn rejection, increasing difficulty budgets, explicit time caps, nonconstant fitted scores and color-relative parity.

`FINAL_RESULT.json` records the successful final-model run and source hashes; every compiled source was rehashed after the run and remained unchanged. `PILOT_RESULT.json` is an explicitly labeled earlier model run, retained for audit history.

This is a local Linux Swift compilation and end-to-end **code path** check. It does not establish iOS project membership, simulator/device performance, XCTest success, playing strength, or a release. Arena results are separate evidence.

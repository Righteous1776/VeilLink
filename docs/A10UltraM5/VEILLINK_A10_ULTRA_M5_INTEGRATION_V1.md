# VeilLink × A10 Ultra Ω M5 Integration V1

## Status

- Chip name: **A10 Ultra Ω**
- Engineering source: OMEGA 96 V0.5-M5
- VeilLink integration state: `TRAINED_COGNITION_SHADOW + GOVERNANCE_ADVISOR`
- LingCore production takeover: `DENIED`
- VeilLink mutation authority: `HOST_ACTION_LAYER_ONLY`
- A10 M5 mutation authority: `0`
- Production cutover: `DENY`
- Real-world/iPhone validation: `NOT_PERFORMED`

## Two independent rails

1. **LingCore cognition shadow** — a dedicated M5 runtime receives the same sanitized `AgentTextRequest` that the visible LingCore backend receives. It produces a digest/latency/token-count comparison only; its text is not shown and it cannot execute tools.
2. **VeilLink governance advisor** — a separate M5 runtime consumes a 32-float host-state feature frame plus host-generated state wording. It returns trained states and non-mutating action proposals such as `REVIEW_SECURE_RECONNECT` or `RUN_READONLY_DB_REVIEW`.

Separate runtime instances prevent cancellation/state contention between cognition and governance evaluation.

## Native path

The original Linux/Python host is not embedded in the app. VeilLink carries:

- pristine trained M5 vocabulary/model identity;
- a canonical FP32 flattened M5 weight asset;
- pristine VeilLink M4 Runtime Predictor model/weights;
- pristine SQLiteVault M4 Anomaly Predictor model/weights;
- a portable C implementation of M5 reasoner, M5 RNN step, and the source-compatible INT8 dynamic-activation M4 predictor path;
- Swift tokenizer/domain/router/render/provenance glue.

Local-host differential evidence in `I12_NATIVE_DIFFERENTIAL.json` compares this new portable C layer with the pristine A10 Ultra Ω native operators for 10,000 random cases per operator, covering M5 Reasoner, M5 RNN, VeilLink M4 INT8 and SQLite M4 INT8. `I12_SPIRIT_SEMANTIC_DIFFERENTIAL.json` additionally validates 2,000 randomized end-to-end Spirit responses (domain routing + state merge + generation + rendering) with zero mismatches.

## Governance boundary

A10 M5 does **not** receive handles for BLE, SQLite, Keychain, SessionCoordinator, game mutation, or tool execution. It can output an advisory proposal. VeilLink decides whether an action is permitted and how it is executed.

The M4 32-feature adapter is explicitly named `VEILLINK_M4_PROXY_V1`: it maps real VeilLink state into the synthetic training feature space, but is not claimed to be a calibrated real-world model.

## Compute budget

Both cognition and governance M5 runtimes respect the existing compute-governance budget. A zero compute budget suppresses Shadow inference; the A9-derived budget is a resource permission, not an A10 reasoning input.

## Promotion requirements

Do not activate M5 as the visible LingCore backend or grant management mutations until at least:

- Xcode/iOS build + XCTest PASS;
- iPhone 7 and iPhone 13 runtime validation;
- long-run thermal/RAM/battery measurement;
- real VeilLink traffic Shadow corpus evaluation;
- zero critical safety regressions;
- explicit Host Action Gate policy per proposed mutation;
- rollback/fallback validation.

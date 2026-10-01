# VeilLink｜A9 → A10 Ultra Ω 双轨接入与最终 Cutover 准则 V1.0

## Locked identity
- Chip: **A10 Ultra Ω**
- Current execution architecture: **OMEGA 96 V0.2**
- Release state: **SHADOW_ACCELERATED**
- Stage 0: **A9 PRIMARY / A10 Ultra Ω SHADOW**
- `PRODUCTION_CUTOVER = DENIED`

## Shared-sample rule
Every VeilLink health sample is created once and carries the same `sample_id`, monotonic `epoch`, timestamp, source domains and privacy-safe signal digest into both rails. A10 Ultra Ω receives the raw host health input through the Host Adapter; it must never consume an A9 Decision as its input.

## Mutation authority wall
During shadow operation A10 Ultra Ω has zero transport/storage/message/game/Agent/key mutation authority. A9 remains production-authoritative. Divergence is telemetry only.

## Divergence taxonomy
`D0_EXACT_MATCH`, `D1_EXPECTED_EXTENSION`, `D2_NON_SAFETY_DIFFERENCE`, `D3_SAFETY_RELEVANT_DIFFERENCE`, `D4_CRITICAL_FALSE_NEGATIVE`, `D5_ULTRA_INTERNAL_FAILURE`.
Any D4 blocks cutover. Unexplained D3 must be zero before promotion.

## Test phases
- Phase A: passive shadow, minimum 100,000 valid common samples with real BLE/foreground/background/thermal/storage/Agent/game coverage.
- Phase B: stress/resource competition.
- Phase C: fault injection including worker/native/RAGE/Vault/epoch/order/SQLite/BLE/thermal faults.
- Phase D: 72 h continuous run or 1,000,000 valid common samples, whichever requirement is stricter.

## Promotion sequence
Stage 0 A9 PRIMARY + Ultra SHADOW → Stage 1 Ultra PRIMARY_CANARY + A9 immediate fallback → Stage 2 Ultra PRIMARY + A9 HOT_STANDBY → Stage 3 Ultra PRIMARY + A9 COLD_FALLBACK → Stage 4 Ultra ONLY.

This I7 package implements **Stage 0 only**. It intentionally contains no production activation API.

## Native runtime boundary
The supplied OMEGA 96 V0.2 native artifact is CPython 3.13 x86_64 Linux and `-march=native`. It is evidence for the A10 Ultra Ω release, not an iOS-loadable binary. I7 therefore loads its release contracts and implements an independent Swift reference shadow runner for the A9-compat decision semantics. A future iOS arm64 OMEGA runner replaces the execution backend without changing the Host Adapter or black-box schema.

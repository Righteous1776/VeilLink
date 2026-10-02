# VeilLink Kernel Runtime Selector V1

Status: I8 / manual comparative runtime modes.

The selector exists to collect comparable black-box evidence for whether VeilLink should ultimately retain A9, retain A9+A10 Ultra Ω, or progress toward a future gated A10 Ultra Ω primary configuration.

## Modes

### A9_ONLY
- A9 evaluation enabled.
- A10 Ultra Ω evaluation disabled.
- Production authority: A9_PRIMARY.
- Purpose: clean baseline for latency, CPU, RSS, thermal, battery proxy and reliability.

### A9_PLUS_A10_ULTRA_SHADOW
- A9 evaluation enabled.
- A10 Ultra Ω evaluation enabled from the same raw host sample.
- Production authority: A9_PRIMARY.
- Purpose: compatibility/divergence and dual-rail overhead measurement.

### A10_ULTRA_INDEPENDENT_GOVERNANCE
- A9 per-sample evaluation disabled.
- A10 Ultra Ω evaluates the raw host signal and supplies the authoritative compute-governance decision.
- Production authority: `A10_ULTRA_GOVERNANCE`.
- Scope: `GOVERNANCE_ONLY_APPROVED`, with `mutation_authority=0`.
- The mode is stable and persistent. Ω runtime failure immediately falls back to `A9_ONLY`.
- This does not promote the separately packaged M5 inference assets or claim a native iOS OMEGA binary.

### A10_ULTRA_ONLY_LAB
- A9 health decision evaluation disabled for the sample path.
- A10 Ultra Ω evaluation enabled directly from the raw host signal.
- Production authority: HOST_FROZEN_BASELINE.
- The last already-committed safe host compute budget remains frozen; Ultra still has mutation_authority=0.
- This mode is experimental and is never persisted across a process restart.
- Any Ultra internal failure triggers automatic mode fallback to A9_ONLY.
- This is not Stage 1 and does not constitute production cutover.

## Black-box environment fields
Every runtime sample records at minimum:
- kernel_mode
- mode_epoch
- mode_session_id
- mode_sample_ordinal
- production_authority
- fallback_policy
- a9_enabled / ultra_enabled
- sample_id / epoch / timestamp / source_domain / signal_digest
- available A9 and Ultra decision/budget fields
- decision_match / divergence_class when comparable
- latency / CPU / RSS / thermal / battery proxy / BLE state / queue depth
- fallback_event
- runtime_backend
- mutation_authority=0
- production_cutover=DENIED

Formal independent-governance samples instead record `production_cutover=GOVERNANCE_ONLY_APPROVED`; all other modes retain `DENIED`.

The mode itself is therefore part of the evidence, not an out-of-band user note.

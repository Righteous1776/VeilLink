# VeilLink Three-Core Plan V1

## Purpose

The A10 Ultra Ω currently being trained is no longer treated as the historical OMEGA 96 governance-shadow concept. VeilLink therefore separates three runtime roles:

1. **A9 Governance Core** — health, safety, persistence, resource budgeting and transport reserve.
2. **A10 Ultra Ω Compute Core** — future real local compute/inference runtime.
3. **LingCore Orchestration Core** — conversation/session/personality/context/tool routing and host control-plane integration.

The old A10 Ultra Ω / OMEGA 96 governance shadow remains as a compatibility harness only. It is not the new compute core.

## Data and authority flow

A9 Governance → `A10UltraComputeBudget` → A10 Ultra Ω Compute

LingCore → sanitized compute request → A10 Ultra Ω Compute → result/stream → LingCore

LingCore → structured host request → VeilLink Action Layer → BLE/SQLite/Game/UI

A10 Ultra Ω never receives direct mutation handles. It cannot directly access BLE transport objects, SQLite handles, identity/session keys, or tool executors.

## Compute ABI

Future runtimes implement `A10UltraComputeRuntime`.

Prepared task lanes:

- text generation
- structured reasoning
- candidate ranking
- game planning
- vision analysis
- embedding

Unsupported lanes may remain unavailable in an early runtime. Capability claims must come from `A10UltraComputeManifest` rather than assumptions.

## LingCore takeover path

`A10UltraLanguageRuntimeAdapter` maps the new compute core into the existing `LocalTextModelRuntime` slot. This lets A10 replace the current mock/llama language-compute backend while leaving LingCore orchestration intact.

`LocalTextModelCoordinator` gains an override slot and a restore-to-base path. If A10 fails, the failed request is not automatically replayed; the host falls back for subsequent requests to avoid duplicate output or duplicate tool actions.

## Legacy shadow separation

The existing `A10UltraOmegaShadow` line is retained for A9↔old-A10 governance compatibility and Cutover evidence. It must not be used as the manifest, state machine or capability claim for the new A10 compute runtime.

## Insertion status

Current phase: `THREE_CORE_INSERTION_READY`.

A10 compute slot: `EMPTY_READY`.

No production claim is made until a concrete A10 compute runtime implements the ABI and passes build, device, thermal, memory, cancellation, fallback and privacy validation.

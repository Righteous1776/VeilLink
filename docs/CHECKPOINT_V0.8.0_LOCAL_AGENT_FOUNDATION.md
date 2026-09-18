# V0.8.0 — Local Agent Foundation

## Exact base

- GitHub `main`: `0d9f54160c05c6ac2d672dda6f056bf831ef546d`
- Base release: V0.7.2
- Base source tree: `6035ce00d77d03f33b51cc3dfb984f329bf0c222`

## Scope

This checkpoint implements work-order Phase 0 and Phase 1 only.

- Adds `.agent` as the fourth root section in exact order: 对话 / 附近 / 灵核 / 设置.
- Adds phone tab and iPad sidebar/detail routing.
- Adds modular Agent Foundation source tree.
- Adds lazy local language-runtime abstraction and deterministic Foundation Mock.
- Adds local streaming transcript, composer, stop generation, new session and privacy-safe diagnostics.
- Adds device capability tiers, background cancellation, memory-pressure trim/unload paths.
- Adds upstream/data provenance locks for fly.ai, MaleCNS v1.0 and secondary FlyBrain reference.
- Keeps the Agent transcript ephemeral; no database migration.

## Non-changes

- Protocol 4 unchanged.
- VLGM1 v1 unchanged.
- SQLite Schema V8 unchanged.
- Tactical game rules unchanged.
- BLE framing/reliability semantics unchanged.
- No MaleCNS graph is shipped.
- No real LLM/GGUF is shipped.
- No cloud dependency is introduced.

## Required release gates

Local Linux validation may check syntax, core API shape, runtime fixture behavior, navigation invariants and historical contracts. Work/macOS must still run XcodeGen, Simulator build, complete XCTest and unsigned `iphoneos` packaging before release. Physical iPhone 7 validation is required before any real-model viability claim.

## Next permitted phase

Phase 2: research and benchmark a real tiny local text model/backend with an iOS-15-compatible native build. Do not begin live MaleCNS tactical control before the separate builder/runtime and generic game-agent phases are validated.

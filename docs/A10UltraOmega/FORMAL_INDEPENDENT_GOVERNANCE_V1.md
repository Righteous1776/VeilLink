# A10 Ultra Ω Formal Independent Governance V1

## Status

`A10_ULTRA_INDEPENDENT_GOVERNANCE` is a formal, stable runtime mode. It is the default for a new installation and may be selected persistently from Settings. In this mode the OMEGA 96 Swift governance runner consumes the privacy-safe raw host sample directly; A9 does not produce the ordinary per-sample decision.

This approval is deliberately named `GOVERNANCE_ONLY_APPROVED`. It is not a claim that the historical CPython/x86_64 OMEGA artifact runs on iOS, and it does not promote the M5 inference assets whose manifests still state `TRAINED_COGNITION_SHADOW`, `NOT_PERFORMED` and `production_cutover=DENY`.

## Authority

A10 Ultra Ω may:

- classify the host health sample;
- choose the governance level and safety reason;
- produce the bounded compute-budget input used by the existing planner;
- reserve capacity for transport/storage recovery and constrain optional compute;
- emit privacy-safe black-box diagnostics.

A10 Ultra Ω may not:

- access identity/session keys or decrypted message content;
- write SQLite, BLE/LAN/relay queues or game state directly;
- execute Agent tools or bypass their permission checks;
- change cryptographic, protocol, VLGM or database schemas;
- self-promote the M5 inference runtime.

The environment therefore keeps `mutation_authority=0`. “Formal governance” means authoritative scheduling and health policy, not arbitrary app mutation.

## Failure isolation

Every mode transition resets Ω persistence and pending comparison state. An internal Ω failure immediately selects `A9_ONLY`, creates a new runtime epoch/session, unfreezes the shared planner and schedules a fresh A9 sample. There is no replay of a partially produced Ω decision.

The former `A10_ULTRA_ONLY_LAB` remains available as a non-persistent experiment with a frozen host budget and restart sentinel. It is not used by the formal mode.

## Acceptance tests

- A10 independent mode disables A9 evaluation, enables Ω evaluation and reports `A10_ULTRA_GOVERNANCE`.
- The mode persists across a normal restart; the LAB mode still cannot persist.
- A green raw sample produces a normal Ω governance budget and a black-box record with no app mutation authority.
- An Ω emergency decision maps through the stable compute contract to an emergency plan with optional training disabled.
- Ω runtime failure immediately falls back to A9.
- Existing M5 asset hashes, source provenance and `production_cutover=DENY` remain unchanged.

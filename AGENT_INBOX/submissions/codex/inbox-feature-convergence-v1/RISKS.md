# Risks and overlap

## Cross-lane overlap

- Many Inbox proposals directly patch `VeilLink/UI/ToolCenterView.swift`. This submission intentionally does not; the Governor must create one final navigation link.
- Mission Control #67/#68 are mutually exclusive implementations.
- Game PRs #27–#35 and entertainment #71/#73/#75/#78/#79/#83/#86 contain version lineages and duplicated paths; selecting the latest verified source per path is required.
- P0 touch/consent/black-box proposals #64–#66 precede feature expansion.
- Practical OSS proposals #81/#84 overlap each other and shared project/Info/Tool Center surfaces; one CodeScanner implementation must be chosen.

## Product risks

- A generic registry cannot prove a feature's own safety or correctness.
- Large descriptor sets still consume memory; integrations should register concise metadata and lazy routes only.
- Launch-gate state must come from trusted integration logic, not a user-editable flag.
- God Mode high-quality rendering can increase battery/thermal load; critical thermal pressure remains non-overridable.
- A future persisted registry requires explicit schema review; this proposal is immutable/in-memory only.

## Release boundary

V27.0 cannot be truthfully published by applying every Inbox patch verbatim. Some entries are planning-only, external-ZIP-only, duplicated, superseded, lack Apple SDK testing, or depend on unresolved iPhone 7 P0 work. The Governor must triage and select; rejected/deferred items remain archived evidence rather than shipped functionality.

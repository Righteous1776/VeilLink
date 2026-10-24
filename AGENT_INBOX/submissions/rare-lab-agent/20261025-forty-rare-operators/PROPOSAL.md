# Feature addition proposal — RareLab R1

## Distinctiveness and scope

Add forty **new**, deterministic, offline technical-analysis operators as an independent feature family, not a renaming of old 20 tools. They target uncommon, high-leverage diagnostics: graph articulation/bridge points, advertisement-channel entropy, RX window starvation, packet reordering inversions, identity namespace drift and iOS touch interaction timing.

## Implementation

- Pure Foundation `VeilRareLab` engine: 40 numbered executors, four groups, anonymous JSON input, 64KB cap, typed bounds, Chinese explanations, sample templates for each group, immutable output string.
- SwiftUI standalone `VeilRareLabView` with query, accessible selectable operator grid, editable example JSON, manual Run/Reset and results. No network/DB/key dependencies.
- Eight XCTest test methods, including exhaustive 40/40 sample and repeatability, critical topology identification, safety, checkpoint, touch and signer failure scenarios.
- ToolCenter one-card integration only, leaving all other controls untouched.

## Product milestones

R1 = interactive offline sample analyzer, ready for Governor consideration, Xcode compile pending.
R2 = additional structured sample profiles / import scrubbing, requiring safe privacy review.
R3 = optional read-only live adapter for public BLE metrics and diagnostic counters, only after user and Governor approval, no automatic authority.

No device transport, secure identity, SQLite, A9/A10, background permission or signing contract change is included or implicitly authorized.
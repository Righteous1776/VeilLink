# Risks — game multiplayer reliability R1

- Apple SDK compilation and XCTest are unverified in this Linux image.
- A physical LAN/relay game was not available, so the non-BLE status correction requires real transport verification.
- VLGM1 has no causal parent pointer. This candidate deliberately does not redesign ordering or conflict semantics.
- Existing queued malformed commands are not deleted or rewritten; only new outbound insertions are blocked.
- PR #97 independently changes BLE connection recovery. It does not overlap this patch, but the combined build still needs the two-device matrix.

Rollback is the clean reversal of the four-file patch; no data migration or protocol rollback is required.

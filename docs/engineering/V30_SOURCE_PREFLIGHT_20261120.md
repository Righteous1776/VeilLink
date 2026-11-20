# V30 Static Source Readiness — 2026-11-20

This note is **not** a real Apple simulator run.

## Staged and inspected
- Source tree now contains R1 flow, encrypted BLE wire types and the R2.1
  ReplayKit extension with both host and extension project target references.
- Local coordinator binds + invite to authenticated BLE capability; player role
  state and image never enter message persistence.
- One source-level optional-binding compile blocker was corrected in
  `VeilScreenCoordinator.received(chunk:from:)`.
- V30 release gate still reports missing 30.0/70 identity, missing compiled IPA,
  unverified AppGroup signing, and absent two-device receipt.

## Cannot currently be asserted
- XcodeGen project generation / iOS framework Swift typecheck.
- Entitlement registration and signed App Group/Keychain interoperability.
- Background screen frames continuing to flow under host suspension.
- Frame legibility, lag, 10-minute thermal, Bluetooth-only stability.

This is source integration, *not a verified app*. Do not merge/tag/release
until exact-head iOS CI plus true sender+viewer device acceptance.

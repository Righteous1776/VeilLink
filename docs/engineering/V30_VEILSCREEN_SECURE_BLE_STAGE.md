# V30 VeilScreen Secure BLE Foundation — source stage only

Base: V30 audit head `ef0928218a75be094616157ee4ab8bd5ac42d7b4`.
Inputs: R1 (#232) four pure Swift protocol/state/scheduler units, no R0 v1 media.

## Implemented
- New Wire v4 kinds 12 / 13 for ephemeral screen control / media.
- Separate AEAD contexts with existing per-session monotonic counters,
  authenticated identity and BLE transport, trusted contact verification.
- Signed *optional* Hello extension for screen capability, tied to v4 signature.
  Legacy capability bits 0..2 remain unchanged. Old v4 Hello decoder can
  discard the new fields without rejecting chat interoperability.
- Shared anti-replay window, exact current session UUID identity, <=512B
  envelope and R1 384B media chunk bounds. Screen data never enters messages,
  attachments, reliable queues, database, backup or diagnostic image logs.
- Four source files copied from vetted R1 branch via exact blob SHA, with an
  additive XCTest for envelope, legacy Hello and chunk validation.

## NOT YET COMPLETE / DO NOT SHIP
- R2.1 ReplayKit Upload extension and App Group/Keychain entitlements not
  configured or signed; no real frames can yet be captured and forwarded.
- R1 chat invite/receiver view not wired; callbacks have no production handler.
- Rate controller and collector/decoder integration to actual BLE not completed.
- No build proof on Apple SDK, simulator tests or signed two-device evidence.
- No continuous background BLE guarantee. Never show an enabled invitation
  until sender and receiver consent, system picker and verified media work.
- No V30 build/tag/IPA, and no GitHub Actions invoked for this stage.

Next integration scope must include real AppModel coordinator, ReplayKit
extension, entitlement validation, native receive viewer and cleanup, then
single consolidated exact-head CI plus owner-device acceptance.

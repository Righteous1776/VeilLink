# V30 screen-share integration and STOP-SHIP evidence

## Integrated product sources on this V30 branch

- R1: typed VeilScreenShareWire, ephemeral session state machine, viewer UI,
  BLE scheduler, and chat card.
- R2.1: ReplayKit Broadcast Upload extension, encrypted single-slot App Group
  mailbox, sender host consent picker, and off-main mailbox pump.
- Signed optional v4 Hello screen capability addendum; existing signed Hello
  content and 7-bit feature schema remain unchanged.
- Typed AES-GCM control/media encrypted under distinct domains; session UUID,
  peer trust and packet replay protection. Nothing goes to chat SQLite.
- Full AppModel, SessionCoordinator, BLE and chat + menu source routing.
- Sender's Apple broadcast consent is explicit. Only video is processed.
- Account identity swap, revoked peer trust or withdrawn app consent
  ends screen session and invalidates transient buffers.

## Unverified / STOP-SHIP

- Complete XcodeGen, Swift typecheck, iOS simulator/XCTest and iPhoneOS build.
- Signed host AND extension App Group + Keychain entitlement distribution.
- Actual 2-iPhone OS picker, first screen frame, BLE decryption and viewer
  picture, stop, disconnect, background and long-running performance.
- Real text legibility at ≤32KiB per compressed JPEG frame.
- Background host BLE continuity is not guaranteed by ReplayKit or TrollStore.

## ECLIPSE conflict arbitration

PR #234 R17.2 explicitly proposes the prominent secondary live instrument
dial and a 0.65 s board impact ripple. Both conflict with the owner's later,
specific instructions to REMOVE them while retaining the upper ECLIPSE robot.
Do NOT wholesale replace the Build69 ECLIPSE UI with R17.2. Selectively
review algorithmic telemetry only, respecting the real 1-10 slider, finite
node/depth guards and cancellation semantics.

## Publication

Not tagged, not a released IPA. No GitHub Actions has been started
for this branch. Use one exact-head candidate CI after a complete
source audit, then signed hardware testing before formal V30 publication.

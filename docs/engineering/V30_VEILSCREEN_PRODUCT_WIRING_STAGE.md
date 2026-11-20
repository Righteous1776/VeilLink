# V30 VeilScreen R1 + R2.1 product wiring — UNSIGNED CANDIDATE

Base: `12b852e67cb88b7f849e16645529c2973301e770`. Source candidates: R1 #232, R2.1 #236. No legacy R0.
This is an integration source stage, **not** successful signed screen sharing.

## Source changes
- ReplayKit Broadcast Upload iOS 15 extension target with separate principal
  class, App Group and Keychain group entitlements on both host/extension.
- Includes R2 shared encrypted single-slot mailbox, secured session keys,
  grayscale JPEG encoder, capture pacer and host-side low-rate pump.
- Adds real AppModel coordinator callbacks for encrypted screen-control and
  screen-media, R1 role-aware invite/accept/READY-ACK/stop state machine,
  single-frame assembler and transient viewer.
- Chat '+' shows invitation option only on authenticated BLE peer with signed
  capability; viewer card is ephemeral and does not enter chat SQLite.
- Media enqueued via BLE bulk priority; queue backlog comes from actual
  central/peripheral pending-byte counters, not synthetic progress.
- Requires local ReplayKit user action; no audio capture, invisible streaming
  or remote-initiated system recording. Cannot promise live host while suspended.
- R1 viewer surfaces use warm ECLIPSE orange over neutral graphite.

## Mandatory release blockers
- Simulator/iphoneos/XcodeGen compile: **NOT_RUN**.
- Real Apple Developer Team, signed entitlement expansion and extension embed:
  **NOT_VERIFIED**. With unsigned provisioning, the picker must fail closed.
- Two consented iOS devices (capture, BLE frame, text legibility, privacy,
  scope/revoke, 10-minute thermal/background) **NOT_RUN**.
- Exact-head V30 gate is intentionally RED until these have receipts.
- Source branch writes do not trigger GitHub Actions (only main push/PR does).

Do not publish/tag V30, call this complete, or hide unfinished status.
## V30 source stage update — November 20, 2026

The staged V30 integration branch now contains a real **source-level** R1 + R2.1
screen-share path: typed authenticated BLE media, ReplayKit app extension,
App Group mailbox, ephemeral coordinator, chat invitation and receiver.
Unlike the Build68 product, these files are now under actual product/target
paths. This is **not** proof of a working IPA or signed two-device stream.

- Source integration: `65dc9e14a60684d32172f3455a7895d6a35e5b98`
- Local release gate self-test: PASS (checks fail closed)
- GitHub remote source/packaging marker scan: 13/13
- Xcode/iOS native build: NOT_RUN
- iPhone sender/viewer signed acceptance: NOT_RUN
- Version 30.0 Build70: not yet changed / no IPA / no release
- CI spending for this branch: zero (not a PR, not main)

No direct main push and no new GitHub Actions workflow dispatch.

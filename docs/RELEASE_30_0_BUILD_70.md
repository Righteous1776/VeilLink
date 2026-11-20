# VeilLink 30.0 (Build 70) — source integration candidate, not release-approved

This document is **NOT** proof of a published/signed/installed release. Publishing is blocked
until exact-head iOS simulator, XCTest, Release iPhoneOS, unsigned IPA structural integrity,
signed App Group entitlement validation and actual two-phone BLE screen-media acceptance pass.

## V30 incident recovery scope
- Introduced an explicitly configured ReplayKit Broadcast Upload extension in the host app,
  used only after a user-initiated iOS consent flow.
- Implemented authenticated BLE-only ephemeral screen-control and bounded video-media
  lanes, separate from chat SQLite and durable file/message queues.
- Added app-owned screen invitation/viewer card under the conversation + menu.
- Revokes capture on local STOP, secure-link failure, peer revocation, identity/consent changes,
  and after the ReplayKit system broadcast is terminated.
- Preserved V29.2 Build69 Gomoku 1–10 real thinking slider, no fixed time cutoff
  with finite node/depth bounds, and ECLIPSE's upper robot identity.
- Excluded user-rejected lower ECLIPSE measured dashboard and board ripple.
- FORGE R2 reused the existing instrument background and warmer orange rounded surfaces.
- Added strict source and compiled-IPA extension receipt gates.
- Historical inbox contributions remain individually triaged; not every Inbox draft is shipped.

## Explicit limitations and stop-ship conditions
- No claim of continuous screen streaming while the host iOS app is suspended.
- Unsigned IPA does not prove that App Group/keychain entitlements function.
- User must knowingly tap iOS Broadcast Start; sharing is visual only, no remote control or audio.
- A source gate is not an iOS executable typecheck or a two-device acceptance report.
- **Do NOT use this document to auto-publish an unverified V30 release.**

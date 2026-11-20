# VeilLink V30.0 · Build 70 — Source-integrated candidate, NOT published

**Integration base:** V29.2 Build68 main, plus tested Build69 source
improvements, FORGE soft orange overhaul, and V30 screen-sharing code.

## Owner-visible corrections carried forward
- ECLIPSE upper robot state remains; redundant lower measured-instruments
  card and decorative board ripple are REMOVED.
- Real 1–10 native thinking-strength slider; user-selected unlimited
  wall-clock search (finite node/depth guards and cancellation still apply).
- FORGE uses ECLIPSE bright orange, rounded instrument panels and the same
  background compositor as the established Instrument appearance.
- Prior accepted chat keyboard/order, BLE queue stability, Apple Files import,
  image compression, Flight Recorder diagnostics and game lobby scrolling
  remain sourced from the Build68 + Build69 integration base.

## New VeilScreen source integration
- Chat + menu real invite, two-sided consent, ReplayKit Broadcast Upload
  extension, bounded AES-GCM encrypted temporary mailbox.
- Authenticated trusted BLE-only screen control and frame lanes with versioned
  protocol, session identity and anti-replay.
- Sender cannot capture another device remotely; sender must explicitly start
  iOS system broadcast; receiver has accept/decline/stop.
- Video only, low-priority BLE; no microphone, no durable media storage.

## STOP-SHIP REQUIREMENTS
- This exact source tree has **NOT** passed iOS simulator/XCTest or compiled
  device IPA verification in the conversation environment.
- Extension/App Group/Keychain require owner-signed provisioning and an
  actual two-phone test before claiming usable system-level screen sharing.
- ReplayKit extension running in background does NOT guarantee host BLE
  networking continues when iOS suspends the application.
- ECLIPSE R17.2 proposal is not pasted verbatim: it restores owner-rejected
  extra dashboard and move ripple; selective review is still required.
- Do NOT tag or publish V30 as final until all required checks are green.
- Candidate CI is permitted once at exact head; avoid iterative CI waste.

## Required published artifact receipts
- Commit SHA and git tree SHA, version/build tuple 30.0/70.
- Simulator build, XCTest, device Release-iphoneos .app.
- Embedded VeilScreenBroadcastUpload.appex extension presence.
- IPA CRC/Info.plist identity and SHA256 parity.
- Owner-signed host/extension entitlement verification and real BLE two-phone
  screen/video/stop/privacy acceptance logs, without pixel/chat contents.

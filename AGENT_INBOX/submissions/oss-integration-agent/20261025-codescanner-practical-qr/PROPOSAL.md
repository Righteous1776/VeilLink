# Practical R1: Make QR actually useful on iPhone7

## What we found in current main

`VeilRemotePairingView` generates 60s QR and imports them from Photos via Vision, but does not provide direct camera scan. `VeilTemporaryQRToolView` generates QR from up to 1024 UTF-8 bytes, but cannot scan another device's displayed QR. `Info.plist` already has a camera permission purpose for agent video; scanning needs a truthful camera usage description.

## Proposed concrete changes

1. Pin exactly **CodeScanner 2.5.2** at `https://github.com/twostraws/CodeScanner.git` in XcodeGen `project.yml`. Upstream tag declares swift-tools-version 5.9, iOS 13+, zero dependencies, MIT.
2. Add `VeilCameraQRScannerView`: real camera capture via CodeScanner (single QR only, no continuous camera), no image storage, no auto-open URL, photo-output disabled.
3. Add pure `VeilQRScanPolicy`: validates nonempty, UTF-8 byte cap 1024 for general text, 4096 for pairing QR, invalid ASCII controls and pairing scheme `veillink://pair?`.
4. Add button to **临时二维码**: scan another phone's QR directly, put opaque text into existing editor; works without internet.
5. Add button to **远程二维码配对**: scan 60s code directly; still passes string to original `VeilRemotePairingCoordinator.consumeQRCode` => original QR decoder, expiry and six-digit mutual confirmation remain authoritative; **remote pairing still depends on configured Internet Relay**, not BLE-only.
6. Keep existing photo QR import intact; use minimum global UI mutations, no new root drag/camera background.
7. Update existing `NSCameraUsageDescription` with explicit local QR scan reason.
8. Unit tests for policy; code scanning and SwiftUI runtime require macOS/iOS15 integration.

## Scope exclusions

No remote pairing crypto modification. No Keychain, BLE, database, identity, signing, A9/A10, user data, version, release, workflow or main change. No copied third-party binary/artwork source. GitHub only receives this proposal in own Inbox.

## Source proposal

`PATCH.diff` contains all updates to four existing files, based on exact main SHA. New files provided under `FILES/`; Integration Governor to place them only in approved feature branch.

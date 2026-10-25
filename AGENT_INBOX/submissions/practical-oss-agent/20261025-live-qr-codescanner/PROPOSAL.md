# Practical OSS R1 — implement real actions, not fake feature counts

## Problems verified in Build 61 source

- Existing `VeilRemotePairingView` displays an expiring 60-second Relay pairing QR and can **import an existing photo** using PhotosUI + Vision; it has **no direct live camera scan**.
- Existing local Tool Center can *produce* a temporary short-text QR, but offers no general camera reader to consume QR text locally.
- `project.yml` includes ZIPFoundation but not CodeScanner; `NSCameraUsageDescription` already exists for another purpose, requiring an accurate disclosure update.

## Practical changes

1. Add `twostraws/CodeScanner` as an XcodeGen Swift package **exactVersion: 2.5.2**, linked only to the app, not the widget. Version's Package.swift declares Swift tools 5.9, iOS 13+, no package dependencies.
2. On `VeilRemotePairingView`, keep original photo-import unchanged, add a visible opt-in camera scan. `scanMode: .once`, an explicit cancel control, and main-thread result handling. Reject oversize/non-base64url QR shapes before calling original `pairing.consumeQRCode`.
3. After receiving a syntactically acceptable QR, invoke the original authoritative codec/Coordinator: 60-second expiry, relay configuration, X25519, encrypted proof and six-digit mutual confirmation are *not* replaced or bypassed.
4. Add `VeilOfflineQRReaderView` with one opt-in camera sheet and a Tool Center link. Cap text at 4096 UTF-8 bytes. Display locally and **copy only on user action** via existing `VeilToolClipboard` local-only/expiration policy. No automatic URL open, network access, database insertion or telemetry.
5. Update camera usage description to accurately describe both scenarios.

## Important transport distinction

The **generic QR reader works fully offline**. The **remote pairing QR scanning camera itself also works offline**, but remote identity exchange still needs the **existing configured online Relay**. This PR does NOT turn remote pairing into BLE-only pairing or implement BLE mesh relay.

## Architectural gates

Zero modification to SQLite, Keychain, Wire v4, identity crypto, BLE runtime, A9/A10 authority or existing picker; the new source is staged only in Inbox. Product and build files are proposed via PATCH.diff for later Governor application, not edited on main.

# VeilScreen R2 — measured vs unverified

## Completed in Linux build container
- `swiftc -O` with **precondition** assertions: iOS 26 -> ReplayKit; iOS 27+ -> SCK; rate pacing drops repeated/out-of-time samples; stale/duplicate/retrograde frames rejected.
- End-to-end bounded R1 media scheduler -> v2 codec -> receiver assembler for 100 frames; replays discarded.
- Swift frontend parse of every iOS-specific candidate source file; not typechecked against Apple SDK.
- Python `plistlib` validates App Group entitlements and Broadcast Upload Info.plist XML syntax.

## Must pass on signed iOS 26 hardware
1. Apple Xcode Swift 5.9/6 compiler full target build, signed app + upload extension registration. Check entitlements `com.apple.security.application-groups` and `keychain-access-groups` on both targets after signing; verify `$(AppIdentifierPrefix)` expansion.
2. Host invite -> viewer acceptance -> host creates session key -> system RPSystemBroadcastPickerView -> user manually starts screen broadcast -> extension receives CMSampleBuffer.video -> ciphertext in group container -> app decrypts and calls READY only after first frame.
3. Dedicated wire v4 extension negotiated between two compatible devices; BLE-only E2EE, trusted identity gating, control/media AEAD domain separation, replay/oversize/malformed/cross-peer rejection, no fallback to chat/attachment path.
4. READY-ACK confirms before any frame transmission; receiver displays actual first frame, stale/expired/stop cleanup, no chat record or snapshots in backups.
5. Third-party app switch, sending phone background 1/10/30 minutes, lock/unlock, low power, call interruptions, peer disconnect, Bluetooth off/on, permission revocation, force-quit, system broadcast stop; measure whether host BLE continues. No claim until hardware pass.
6. Privacy: microphone/system audio never enters wire, session keys only Keychain, no plaintext files, no persistent frame history, App Group ciphertext file wiped after STOP and at next launch.
7. Visual: test small Japanese/Chinese font labels and UI icons at 240/320/540px; include 2x zoom/ROI fallback if unreadable; chat latency while screensharing under 2/5/10 KiB/s measured encrypted goodput.

## Known blockers
No Apple toolchain here; cannot certify `RPBroadcastSampleHandler` compile, App Group signing or two-device BLE throughput. Under iOS26, App Group can hold only the newest ciphertext while host is suspended; it cannot itself guarantee uninterrupted live video delivery.

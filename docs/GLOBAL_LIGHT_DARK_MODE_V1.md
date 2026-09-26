# GLOBAL_LIGHT_DARK_MODE_V1

## Purpose
Turn the previously accidental light Instrument rendering into a supported application-wide appearance system and remove split sources of truth that could leave the lock screen in a stale light/dark state.

## Contract
- UI skin and color mode are independent dimensions.
- Skins: Veil Original / Apple Soft / Instrument.
- Modes: Auto / Light / Dark.
- The selected mode applies before AppModel exists, so onboarding, legal gate and lock screen use the same appearance as the main app.
- iOS 26 Liquid Glass remains a platform-material layer, not a user toggle; it consumes the effective color scheme automatically.
- No communication, database, E2EE, Wire Protocol, relay, BLE or LAN behavior is changed.

## Stability changes
- Removes the hard-coded `.preferredColorScheme(.dark)` app override.
- Explicit modes cannot be overwritten by transient UIKit traits during scene/background/biometric transitions.
- Lock screen observes the shared appearance source directly.
- Lock-screen keypad reuses shared skin surfaces, reducing duplicate clip/shadow work on iPhone 7.
- Color-mode switching deliberately disables global view animation; cards do not individually cross-fade/re-layout.
- UIKit navigation/tab chrome reads the shared palette rather than fixed dark colors.

## Day palettes
- Veil Original: new warm ivory/gold day palette.
- Apple Soft: existing soft Apple day/night palettes.
- Instrument: day palette refined to the warm off-white/orange state seen in the supplied real-device screenshot; existing night palette retained.

## Validation still required in Xcode / device
- XcodeGen + iOS SDK typecheck
- XCTest
- Simulator Light / Dark / Auto matrix
- iPhone 7 scene/background/lock/unlock transitions
- Current-device iOS 26 Liquid Glass Light / Dark matrix
- Unsigned iphoneos Release IPA

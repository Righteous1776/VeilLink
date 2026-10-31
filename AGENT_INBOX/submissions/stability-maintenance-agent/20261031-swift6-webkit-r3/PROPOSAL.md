# Proposal — concurrency warnings and WebKit navigation policy callback

## Scope
1. Add `@MainActor` to `RhythmParticleTexture` since its only consumer is main-actor `RhythmNeonScene` and UIKit texture creation requires UI isolation.
2. Replace `Date.init` implicit `@Sendable` conversion with an explicitly sendable closure in `VeilStorageMaintenance`, unchanged time semantics.
3. Change `VeilVoicePlaybackController.audioPlayerDidFinishPlaying` to nonisolated delegate witness: capture the **ObjectIdentifier** of the just-finished audio player, then hop back to MainActor and only stop when its identity still matches the active player. This avoids late callback stopping a newly started track and avoids transporting an AVAudioPlayer across concurrency isolation.
4. Mark free `metric()` SwiftUI helper `@MainActor`, matching the view-only UI modifier it invokes.
5. Extra file `FILES/PR100_WEBKIT_FOLLOWUP.diff` targets ONLY PR #100 exact head `ced1cd0e1f561dfdb702eaa08a9a03da7ec6b00f`, **not main**. It fixes the Apple-confirmed `WKNavigationDelegate` decision handler witness type: `@escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void`. The compiler warned the old handler 'nearly matches' but does not prove callback registration. Failing to call the callback could let untrusted navigation proceed, so this is a priority candidate. Governor must first select a single Monogatari integration line (#98/#99/#100) and rebase this one-file suggestion onto it, not import all duplicated proposals.

## Remaining intentionally unresolved risk
- `PlatformerScene.didBegin/didEnd` has a Swift6 nonisolated contact-delegate warning. Simply using `@preconcurrency` hides a warning but is not a correctness proof. A safe real fix needs a main-thread physics callback design that preserves `SKPhysicsContact` / `SKPhysicsBody` scene identity and ground-contact ordering without moving non-Sendable SpriteKit references across actors. This project requires real SpriteKit tests, so **not patched blindly**.
- Runtime WebKit external URL / iframe navigation tests are mandatory after delegate fix; successful simulator compile alone is not proof. The addon is branch-scoped.
- Do not flip `SWIFT_VERSION` to 6 until all diagnostics and third-party compatibility are addressed; current strict concurrency is set to complete but language is 5.9.

## Risk and acceptance
Exact-main file-context patch checks; Apple SDK compile/test; ensure no new actor isolation errors, texture used only from main actor, audio finishing old playback cannot stop newer playback, no UI warnings. For #100: check exact protocol method witness and exercise the runtime navigation policy against external URLs. Do not release without physical iOS15 verification.

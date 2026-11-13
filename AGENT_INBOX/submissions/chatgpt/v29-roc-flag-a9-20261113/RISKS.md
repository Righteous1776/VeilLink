# Risks and overlaps
- INBOX_ONLY staged source patch. New SwiftUI Text(Image) uses available inline-image initializer for iOS 15; Image rendering must be original-color. SwiftUI Text concatenation is supported on iOS15 but deprecated in newer SDKs, so future modernized design may use interpolation after dedicated localization tests.
- Emoji supported within app only where a user-visible Text field is explicitly passed through the adapter. Native UIKit text editors/keyboard and OS-level Text rendering outside VeilLink's own views are NOT controlled.
- SVG/PNG binary assets are forbidden by governance; custom drawing uses UIKit Graphics and SwiftUI, no external copyright or asset override. Official geometry is based on Article 4 of ROC law; in-app 24×16pt raster may antialias fine rays on older small screens. Need actual visual screenshot check.
- Previous PR #192 edits `VeilA9HealthMonitor.swift` and runtime diagnostics for not-evaluated states. This patch edits `SettingsView.swift` only, complementary to PR192; Governor decides integration order and tests overlapping user-visible health behavior.
- Current PR #184/#188 touch Veilopoly UI, not this conversation UI; still inspect current main before integration. No merges, workflow_dispatch, build/release or IPA in this task.
- Unexpected platform color-tint propagation, VoiceOver grouping and iOS15 CoreGraphics behavior need device testing. No statement that the system globally supports the flag.

## Optional composer-access notes
- The shared 8-digit historical access code is only a discoverability gate. The digest can be extracted and brute-forced (and PR/git history inspected). No technical claim of secrecy or legal/personal safety can be made. For actual privacy, opt for a private repository, device-level controls and a user-chosen secret; don't confuse any renaming with protection.
- New `VeilComposerOptionGate.swift` depends on Apple CryptoKit (available on iOS15). `ConversationViews.swift` now includes an extra image/file pathway; it explicitly invokes existing ImageTranscoder/sendImage, not manual network primitives.
- The graphics attachment requires client authentication and a ready peer as usual. A recipient with another app may still not render native flag Unicode; an actual sent picture remains readable.
- New composer UI changes the same `ConversationViews.swift` as the pre-existing PR #195 flag rendering proposal, by design. Owner requested this revision before product merge; update the one proposal rather than stacking another overlapping PR.
- Popup presentation, confirmationDialog on iOS15, sheet lifecycle, cleanup and RAM usage require real iPhone 7 tests. No release or live integration authority.

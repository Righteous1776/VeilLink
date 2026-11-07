# VLP-CODEX-W1-004 — coherent interface theme

Before: 8865668dcf7ca0ba61f1a3b82a9073f156afa774, dev/veilopoly.
Main rechecked: 2c5b5161027edff097b27fe3323d30f6ca3e430e. #168 grant only.

Cause: UI root forced dark while table toggled; root/board backing stayed bright;
guide forced light; news stayed ivory; nested numeric sheets could inherit the
instrument panel's scheme instead of the chosen game theme.

Fix: one UI-only palette derived from existing dayFelt, propagated as an
Environment value. Root/native dialogs, numeric sheets, guide, board backing
and news follow it. Guide/news ink, secondary ink and text gold use opaque
contrast-tested colors. Astra controls/stock terminal remain explicit dark
instrument islands, preventing black semantic text on signed dark textures.
Physical ivory card art remains ivory deliberately; no art bytes/aliases changed.
No new gameplay preference, saved-state field, rule or RNG behavior.

Executed:
- `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 --filter InterfaceThemeTests`
  → 4 tests, 0 failures → PASS. Covers day/night mapping, dark surround, bounded
  sRGB channels, >=4.5:1 numerical contrast on guide/news opaque surfaces.
- Same full-package command without filter → 248 tests, 0 failures, 38.559s
  Linux Swift 6.2.1 → PASS.
- ARM64 iOS15 frontend parse of six affected SwiftUI sources → exit 0 → PASS
  (grammar only; rerun after final diff review required before commit).
- `git diff --check` → no whitespace errors → PASS.

NOT_RUN: Apple SDK type-check/XCTest, screenshots, modal environment propagation,
VoiceOver, actual display/color-space contrast and iPhone/iPad day/night taps.
Numerical contrast tests are not screenshot or accessibility certification.
Existing strict-build Codable warnings remain; not suppressed or relabeled PASS.
Governance skill supplemental seal/session/learning files still absent: PARTIAL,
not a fabricated gate. Existing Owner/#168 live-lane and Inbox rules unchanged.

Next: VLP-CODEX-W1-005 — minimum touch regions for animation skip and stock
portfolio controls. Full HUD drag/clamp and Apple UI acceptance remain open.

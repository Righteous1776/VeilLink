# Risks

## Protected surfaces / governance
Only advisory PATCH.diff in own Inbox. Source/actor changes require Governor patch application. No main, no signing/version/release/IPA changes.

## Overlap
#100 Monogatari WebKit file is not in current main; branch-specific appendix `FILES/PR100_WEBKIT_FOLLOWUP.diff` must not be applied to main, and conflicts with #98/#99 selection. #86 has rendering work and #102 has ToolCenter UI changes. Governor decides.

## Semantic risks
Nonisolated audio callback reorders completion through MainActor task, but guards by player identity; needs actual audio device validation. MainActor annotation on UI helpers could surface call-site isolation diagnostics; reject if Apple CI errors. SpriteKit contact warnings remain unresolved rather than suppressed.

## Privacy and security
WebKit delegate policy should be fail-closed on nonlocal navigations. This source-only patch cannot certify runtime callback dispatch or origin security. Test actual WKWebView. No user identifiers/secrets written.

## Rollback
Drop patch per file or revert isolated integration commit, retaining previous audio semantics until XCTest and device tests prove no regression. Keep #100 fix separately to avoid overlapping branches.

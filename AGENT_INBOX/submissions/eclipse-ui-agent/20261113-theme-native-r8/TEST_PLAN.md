# Verification matrix (R8 continued work)

## Completed
- Swift 6.2.1 Policy compiled strict warning-as-error; 15/15 assertions PASS.
- SwiftUI source passes swiftc -frontend -parse -swift-version 5; NOT TYPECHECK against Apple SDK.
- Original GitHub main SHA eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0; 4 intended current-main source anchors matched exactly via fetched full source files.
- Full code advisory PATCH.diff in local owner ZIP, SHA-256 6e45c693af9b7036bd9be66ec9688e32ecd56a22d8eca46d636a5b9cc61c3af8, was regenerated from exact numbered current-main excerpts; no stale synthetic placeholder inside diff.
- git apply --check + git apply on a reconstructed **true-excerpt** partial baseline PASS; resulting source has a single Gomoku ECLIPSE card, other Grok path and no live overlay.
- HTML R8 preview Chromium 320×568, 390×844, 768×1024 widths; each tested all five themes; postgame-only replay, no hint leakage, no horizontal overflow or errors.

## Required before integration
- Full current main git checkout and git apply --check (not completed in this isolated Linux container).
- Actual iOS Xcode build/typecheck, XCTest, VoiceOver/Reduce Motion/Dynamic Type.
- Physical iPhone/iPad testing with all 5 themes and System/Light/Dark.
- Verify match journal reconstruction after resumed, interrupted and finished games.
- Confirm serialized telemetry is sanitized and session/run ID checked by future R5 engine bridge.
- Confirm upgrade and old training/database compatibility, then Governor triage.

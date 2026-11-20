# V29.3 / Build 69 — Stability candidate R1 (2026-11-15)

**Status: integration-only; NOT released, NOT signed, and NOT a confirmed fix for all app-wide stalls.**
Base: main v29.2 / Build 68, commit `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.
This branch intentionally does **not** bump `project.yml` yet; that is reserved for a reviewed, exact-head CI-green release promotion.

## Concrete product changes

1. Photo transcode: ImageIO encoding uses detached utility-QoS work rather than user-initiated QoS, to reduce competition with UI rendering, scrolling and touch handling. The calling async task now propagates cancellation to detached work using a cancellation handler; cancelled work checks before decoding and around the decode boundary, and the existing per-output candidate loop already checks.
2. Device profile: explicitly recognize `iPhone14,4` (iPhone 13 mini) and `iPhone14,5` (iPhone 13), both 4 GB A15 models. Use balanced transfer animations, avoid eagerly precomputing transfer shards, and coalesce chat refresh by 110 ms. Keep the 2,000-message maximum window, 32-MiB thumbnail cache and standard 4-GB-class BLE limits. iPhone 13 Pro and iPhone 7 policies are unchanged.
3. Add XCTest contracts for current-task cancellation and both newly recognized device models.

## Evidence and acceptance gates

- GitHub PR exact-head macOS CI: `swift test`, iOS simulator, XCTest / UI smoke, unsigned iPhoneOS build, integration receipt, and IPA integrity.
- **Device check** (not replaceable by CI): iPhone 13/mini rapid photo sends while navigating and scrolling; cancel during large image compression; screenshot text readability; heavy game lobby vertical swipes; memory/thermal behavior and no leaked/deadlocked workers.
- Capture before/after long-task and gesture stalls with the existing privacy-bounded Flight Recorder R5 without chat plaintext, screenshots or keyboard content.
- Do not claim an improvement in frame latency, BLE throughput or battery until traces are compared.
- Validate both phones and prior local data before tagging `v29.3-b69`. The current release `v29.2-b68` remains intact.
- Screen sharing ReplayKit + BLE transport and ECLIPSE R17.2 are **out of scope**; their Inbox work is not ready for user-facing release.

## Rollback

If CI or device testing fails, close or revert only this branch. Do not reset message tables, protocol or user data. Revert changes in `ImageTranscoder.swift` and `DevicePerformanceProfile.swift` independently if regression isolation requires.

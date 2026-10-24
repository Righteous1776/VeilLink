# VeilLink 26.14 · Build 60 — Full Inbox Integration Candidate

This is a cumulative Governor-controlled integration of VeilLink 26.13 Build 59 plus selected, reviewed Inbox proposals. This document describes the **candidate source tree**; publication and functionality remain unverified until CI/XCTest and compatibility gates are completed.

## Integrated source

1. **#55 — Day/night reactivity:** central appearance-controller observations across instrument, ambient, card and Apple Soft surfaces, with regression tests.
2. **#51 — Lifecycle:** single-flight lifecycle and memory-pressure coordinator to prevent duplicate transitions.
3. **#49 — Local file integrity:** bounded streaming SHA-256, two-file comparison and privacy-safe reports.
4. **#52 — Conversation workspace:** offline history analysis, message forge and confirmed local quick-clear.
5. **#56 — Wire v4-compatible R1–R5 and SQLite v10:** separately signed optional Hello capability proof; encrypted control-event kinds 10/11, peer capability negotiation, durable per-recipient control outbox with receipt/retry, SQLite v8 → v9 → v10 migrations, and associated regression tests. **Protocol version remains v4; extension is optional.** Never use a cached capability as proof of current session trust.
6. **#50 — Storage management:** storage classification, cleanup guardrails and bounded maintenance with regression tests.
7. **#53 — TrollStore capability detection and compact settings:** diagnostic installation-source evidence and expandable settings, without private entitlements or implicit elevated capability.
8. **#57 — TrollStore readiness policy:** opt-in/probe-based future gate with denial and safety fallbacks.
9. **#54 — Adaptive particle compositor:** native effects with Reduce Motion, thermal/low-power and legacy-device safeguards.
10. **#58 — R5 database arbitration/checker:** SQLite migration structural preflight fixture and single migration ownership by #56; does not implement a second competing schema.

## Inbox arbitration / not blindly included

- #53's proposed future SQLite v9 persistence design is a document, **not an additional migration**: #56 is the only database migration implementation.
- #50 and #53 SettingsView hunks have been replayed in order; #51 and #54 lifecycle/root modifications have likewise been integrated on a single product tree.
- Legacy game Inbox drops #21, #25, #27–#34 and V3 #35 are not copied wholesale. Most overlap previously shipped 26.12 games; V3's patch declares already-present source files as new, so blind application would overwrite later versions. It requires a separate content/asset migration audit.
- Stale/overlapping tool and maintenance proposals remain under review rather than silently overwriting newer product code.

## Required gates before shipping

- Exact SHA/static preflight, including the synthetic v9/v10 SQLite structural regression, XcodeGen and iOS 15 simulator build, full XCTest and Core unsigned iPhoneOS build.
- Database migration against an actual backed-up v8 database; preserve existing conversation records and attachments, perform repeat-launch and rollback analysis, and check integrity/foreign keys.
- Original v4/R2/R4/R5 handshake and BLE/LAN encrypted interoperability, including low-MTU iPhone 7 BLE fragmentation, optional signature tamper/downgrade behavior, and message/media compatibility.
- iOS 15/iPhone 7 and modern-device smoke checks for appearance, settings, lifecycle, storage cleanup, and particle performance.
- Release artifact provenance, SHA-256, size checks, and monotonic version/build identity.

Wire v4 base signature, identity pinning, A9/A10 governance and signing policies must remain protected. The IPA, when verified, is **unsigned** and requires valid installation signing/provisioning on standard iOS. A source-integration commit alone is not proof of a shippable app.

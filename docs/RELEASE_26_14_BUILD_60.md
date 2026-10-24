# VeilLink 26.14 · Build 60

Build 60 is a Governor-controlled integration of four previously Inbox-only proposals into the cumulative VeilLink 26.13 baseline.

## Included features

- **Appearance reliability (#55):** observe the central appearance controller from ambient backgrounds, cards, instrument/glow surfaces, and Apple Soft material renderers; reduce forced Light/Dark palette tearing.
- **Lifecycle stability (#51):** deduplicate SwiftUI/UIkit root-appear and scene-phase handling, orderly foreground/background delivery, and coalesced memory warnings.
- **File integrity laboratory (#49):** offline SHA-256 hashing of local files with bounded streaming, manual two-file comparison, cancellation handling, and privacy-safe report output.
- **Conversation workspace (#52):** locally analyze existing chat history into action items, unanswered questions, URLs and attachments; add deterministic message templates and manual preview; surface safe clear actions with explicit confirmation.

## Compatibility and exclusions

- Minimum supported iOS: 15.0 (main application). The background widget retains its separate minimum version.
- Existing Wire Protocol 4, SQLite Schema V8, identity/key/transport contracts, and A9/A10 authority are unchanged.
- Protocol+database R1–R5 (#56), future TrollStore environment/readiness (#53/#57), storage management (#50), adaptive particles (#54), and unreviewed historic game Inbox submissions are **not included**. They require independent merge and compatibility gates.
- The Core IPA is **unsigned**; installation on ordinary iPhones requires appropriate signing/provisioning.

## Verification and release criteria

Release only from a verified product integration tree after GitHub Actions static preflight, XcodeGen generation, iOS Simulator build, full XCTest, unsigned iPhoneOS Release build, resource isolation and size checks, SHA-256 and provenance verification. The authoritative result is the exact commit's Actions/Release evidence; this release note is not proof that those jobs have passed.

iPhone 7 iOS 15 / modern iOS physical-device checks for appearance switching, IME, lifecycle and local clear remain necessary. No claim of finished BLE/SQLite R5 migration is made.

# Risks, boundaries, overlap

- **Known repro**: Owner iPhone 7, iOS 15.8.3; light+force-quit+relaunch restored event interaction. This does not prove theme causation.
- **Overlap**: PR #55 appearance reactivity patch already integrated by Build 60; PR #51 lifecycle patch likewise. No overlay of their algorithms; instrumenting only App root / legal UI call sites.
- **Conflict**: existing LegalConsentGateView has prior Kimi IME fix. Retain its custom UITextField and marked-text validation exactly; do not restore old disabled-button code.
- **Privacy**: no free-form event strings, typed text, diagnostic snapshots of private content, raw Keychain/SQLite data or network transfers. A temporary session label, version and theme are collected.
- **Persistence**: best-effort 128-entry JSON ring in Application Support, no secrets. File-protection restrictions/low storage are nonfatal. File exported into temporary directory only on an explicit tap; OS share sheet is user-mediated.
- **Performance**: at most one small atomic file write per enumerated UI event; confirm latency and hit-testing on A10/iOS15.
- **Availability**: does not capture crashes before the first call in @main init or if iOS kills the process before the file write.
- **Behavior**: observability hotfix, not proven resolution of theme-dependent interaction bug.
- **Release**: no automatic IPA. Existing v26.14-b60 remains current until Governor-controlled integration and CI release.

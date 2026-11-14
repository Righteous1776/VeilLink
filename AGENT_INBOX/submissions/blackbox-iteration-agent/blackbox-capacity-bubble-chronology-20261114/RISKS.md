# Risks, overlap, and required arbitration

## Known overlaps / governance
- `AGENT_INBOX/submissions/diagnostics-agent/preconsent-blackbox-ios15-20261024` changes pre-consent diagnostics and requires semantic collision review.
- PR #64 and PR #66 concern diagnostic/touch recorders and may intersect UI event collection. Do not merge automatically.
- Current V29.1 Build 67 main is released; changes must not cause version rollback, hidden behavioral mutation or accidental duplicate release.
- All files under this submission are staging artifacts; no active live lane was granted. Product sources and tests remain untouched on main.

## Risks
- **Storage pressure:** 192 MiB is a configured retention *budget*, not a guarantee of available space or a hard upper bound on temporary ZIP staging. Large ZIP export may require additional free storage for snapshots and output. Add disk-availability UI/quality-of-service gates if hardware testing demands it.
- **Telemetry volume:** first observation of 2,048 rows emits many short events. Large history reload or reordering can cause additional writes; delta filtering reduces but does not eliminate this. Benchmark power and main-thread latency.
- **Metadata privacy:** direction and timestamps can reveal communication patterns even without text. An exported bundle is sensitive; remain local by default, share manually and redact unneeded identifiers. Search query/body remain excluded.
- **Token churn:** session-local tokens reset after 20,000 mappings; `token_epoch` separates generations. Events `no_longer_visible` indicate only row absence from the observed window, not deletion or remote unsend.
- **Memory:** loading newer 8 MiB segment as Data/String still consumes temporary RAM; test with constrained memory and older hardware. Do not raise pending RAM backpressure.
- **SwiftUI compile:** ConversationViews.swift is large and previously hit expression type-check timeouts. Patch adds ordinary statements inside existing closures only, but exact Apple build is required.
- **Test fixture assumptions:** legacy seven-rotation sentinel updated for 15 rotated files; regression suite must confirm no other source/tests assume a 2 MB/128/2,000 limit.
- **Permission boundary:** owner request to extend lower-level inspection must not be construed as permission to breach iOS sandbox, access other apps, scrape unconsented logs or recover plaintext.

## Status
- Static diff replay: PASS
- iOS compile / XCTest / device runtime / IPA: NOT_RUN
- Security and privacy integration review: REQUIRED
- Product integration: NOT_APPLIED

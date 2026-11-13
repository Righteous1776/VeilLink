# Review gates and risks

- Default INBOX_ONLY. Swift candidates and unified patch live only below this one AGENT_INBOX submission. No product source was edited or compiled. Main integration and release are NOT authorized by this drop.
- `CryptoKit` and ZIPFoundation/iOS15 testing require Apple toolchain. Host test imports ZIPFoundation (an existing app target dependency) but test module visibility must be verified by Xcode; adjust test target dependency only via approved integration if necessary.
- Streaming JSONL parsing uses a 64KiB maximum line buffer; larger records are explicitly counted as invalid (never silently claimed valid). Existing exporter has per-record bounded metadata but check extreme payload edge cases.
- Writer's fallback `truncate(atOffset:)` on partial write is best-effort; disk full/protection failures could still leave a partial JSONL record, but the new inventory flags it. A 4MiB memory cap intentionally sacrifices oldest unsaved lines after repeated failures; dropped line count is exposed in manifest.
- Export time now synchronously copies up to eight 2MB logs behind a serial write queue to avoid snapshot races, potentially causing a short UI wait; profile on iPhone7 and consider background staging in a later explicitly authorized revision if necessary.
- Added manifest/index fields change diagnostic EXPORT FORMAT metadata but do NOT alter Wire4, SQLite schema, account identity, or game save. Backward consumers should ignore unknown JSON keys; verify with older log readers.
- Default A9 decision can be green/100 before any real evaluation. This proposal reports "not evaluated" instead of claiming connection health. Health view UIs outside `report()` must be separately audited.
- Orientation callback suppression changes diagnostics only. Touch handling and gesture recognizers are untouched; no claim about physical swipe responsiveness.
- Signal11, 880MB peak, 7.849s hang, and 8 BLE retries require exact reproduction/dSYM. Do not claim the diagnostic fix closes Issues #185 or #191.
- External black-box ZIPs have sensitive content and were not uploaded into GitHub.

## Write-first rotation tradeoff
- Successful large buffered append can produce a >2MB active log before post-write rotation. With a 4MB emergency buffer this can transiently exceed the preferred single-file size; the rotation ring remains bounded in number of files, but actual bytes must be profiled during disk recovery.
- If rename/rotation fails AFTER append, the newly written record remains in the active file. This version still inherits legacy best-effort filesystem rotation and cannot guarantee atomicity across all eight files; a future governor-authorized transaction journal may be warranted. Never delete previously persisted forensic records merely to retry a failed append.

# Verification / regression plan

## Executed
- [x] Read live main governance files and Issue #6.
- [x] Pin the patch to main `af3d823546c288169d19cb3033a6111977d28bd7`.
- [x] Generate unified diff over exactly eight files and validate every hunk against live main (context/replay).
- [x] Confirm no production source, workflow, version, release, database or protocol file was mutated.
- [ ] Apple simulator compilation and XCTest — **NOT_RUN** (no Apple Xcode environment in this session).
- [ ] Physical device export, disk-full behavior and privacy audit — **NOT_RUN**.

## XCTest additions in PATCH.diff
1. Assert configured diagnostic retention budget = 192 MiB.
2. Write records; force flush through export; cold-reload; verify 12 ordered sequences and last event.
3. Assert `DiagnosticBubbleTracePolicy.metadata` only has allowed structural fields (no body, IDs or free-text).
4. Extend pre-consent persistence/ring test from 128 to 512 through 520 events and relaunch.
5. Move oldest-rotation sentinel fixture from `runtime.7.jsonl` to `runtime.15.jsonl`; retain failed-append safety coverage.

## Mandatory pre-merge testing
1. XcodeGen generation; iOS simulator build; run `DiagnosticLogStoreTests`, `BlackBoxExportIntegrityTests`, `PreConsentBlackBoxTests` plus full XCTest/UI smoke on exact applied SHA.
2. Stress `recordVisibleBubbleOrder`: first page, append one message, delivery change, prepend older page, local delete, search filtering, game-card visibility, two conversations, 20k-token reset. Verify ordering and no excessive duplicate events.
3. Send literal sensitive sentinel strings as message bodies and search queries. Inspect every JSONL, index, manifest, ui-state and ZIP entry: zero message plaintext, zero original message/conversation IDs for the new bubble events.
4. Simulate out-of-space, data-protection denial and interrupted append; ensure no prior JSONL rotation/deletion before a successful write. Reopen and assert unique ordered sequence and counters.
5. Export with 192 MiB retention and 64 MiB auxiliary. Benchmark resident memory, foreground animation, disk usage, ZIP integrity and file hashing. If device storage is insufficient, surface honest export error without data corruption.
6. Verify pre-consent recorder works prior to legal acceptance without ever starting AppModel, Keychain, BLE, SQLite or the full diagnostics bridge.
7. Confirm no additional iOS entitlement/permission prompts and no cross-app data access.
8. Check iPhone 13/iPad behavior; do not claim older-device acceptance without hardware test.

**Gate:** no product promotion or signed/unsigned IPA publication solely on this Inbox drop.

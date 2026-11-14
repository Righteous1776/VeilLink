# Proposal — Black Box 192 MiB + privacy-safe chat bubble order

## Scope and implementation

The current main revision V29.1 Build 67 has an approximately 40 MiB configured retention budget (2,000,000-byte active+7 rotated JSONL segments plus 24 MiB auxiliary), an in-memory 2,000-entry timeline and a separate 128-event pre-consent ring. Messages revisions exist, but they cannot reconstruct the order of actual rendered chat rows.

The patch raises the configured **runtime retention budget** to **192 MiB**: 16 × 8 MiB JSONL segments (one active, 15 rotations) + 64 MiB auxiliary; increases auxiliary per-artifact allowance to 16 MiB / 48 filenames (subject to 64 MiB aggregate trim); increases the UI in-memory window to 6,000 events; and increases pre-consent fixed-event ring to 512 entries. The pre-consent recorder remains isolated from AppModel, BLE, SQLite, Keychain and consent-gated services.

The cold-reload reader now traverses newest files and rows first, decoding only the newest 6,000 records rather than every retained JSONL entry. The 4 MiB pending RAM backpressure limit and 1.5-second flush cadence are intentionally unchanged. Rotation remains post-successful-append, and the ZIP manifest continues to count only physically included file records with per-file SHA-256.

## Chat bubble event contract

The ChatView observation point is the final `visibleMessages` collection, after session-card/protocol filtering. The UI observes this at message reload, workspace load and local search filter changes. RuntimeDiagnosticsBridge emits:

- `chat.bubbles.window`: session-local conversation token, window start/count, total visible, changed/removed counts, older-page flag and fixed reason.
- `chat.bubble.order`: session-local ephemeral bubble token, zero-based visible ordinal, inbound/outbound, delivery state, sent timestamp, attachment presence and a literal `plaintext_recorded=false`.
- `chat.bubble.no_longer_visible`: ephemeral token of an item leaving the observed display window (not a claim that it was deleted).

First snapshot writes the visible window; subsequent snapshots write only changed rows and disappeared tokens. At most the newest 2,048 visible rows per observation are enumerated. In-memory token mapping is capped by a 20,000-entry reset; epoch metadata distinguishes token resets; at most eight conversation snapshot maps remain cached.

**Privacy boundary:** no `ChatMessage.body`, reply text, draft, search term, screenshot, media payload, persistent message ID, peer ID or content hash is added to this logger. Persistent IDs are used only inside a temporary runtime mapping to ephemeral monotonically numbered tokens. The metadata function has no string payload or message-ID parameter. Added sensitive-key fragments further redact accidentally supplied chat text fields in generic diagnostic metadata.

## System permission boundary

The app may observe **its own** UI, message state, transport health, storage failures, memory/thermal indicators, and public iOS telemetry APIs under existing authorized entitlements. The proposal does not claim or attempt cross-application log scraping, private conversation access, OS sandbox escape, silent microphone recording, background capture beyond iOS policy, or privilege escalation. All new chat diagnostics remain on-device until the owner explicitly exports the bundle.

## Data compatibility

No database migration, wire format mutation, key or protocol change. Existing JSONL schemaVersion 2 decodes unchanged; both old and new segment names are read. Older pre-consent fixed-event JSON arrays decode under the 512-entry cap. No app/build version change and no IPA generated.

## Integration gates

Apply only via Governor-selected integration branch, review pre-consent overlap, run macOS simulator compile + XCTest, verify privacy artifacts, stress 10k+ records with truncation/rotation failures, run full product CI and manual device export. Reject or revise if UX, memory, availability or privacy regression occurs.

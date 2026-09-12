# V0.3.9 Performance Overhaul

VeilLink 0.3.9-dev build 15 is a performance checkpoint based on GitHub main `aadb80b02e2fc4eeab3d4032d392cd37267e82fc` and includes the pending V0.3.8 iOS 15 stable-scroll correction.

## Main-thread and history work

- Normal ChatView refreshes use an asynchronous recent-history query rather than synchronously decrypting the entire conversation on the main thread.
- Initial history is bounded to 120 messages; older history is expanded in 120-message windows up to 2000 for interactive browsing.
- Full-history decryption is only requested when the user actually types a search query.
- DatabaseStore keeps a bounded 512-entry cache of immutable decrypted message bodies to avoid repeated ChaChaPoly work on delivery/progress refreshes.

## Image memory and transfer finalization

- Image bubbles use ImageIO thumbnail creation capped at 1024 px rather than `UIImage(data:)` full-resolution decode.
- A 32 MiB cost-bounded NSCache reuses display previews across SwiftUI cell reconstruction.
- Inbound attachment finalization now reads/decrypts ordered 48 KiB chunks through one prepared SQLite statement and computes SHA-256 incrementally in the same pass.
- The verified digest is reused when storing the final attachment, avoiding a second full-image hash.
- Outbound encoded attachment cache ceiling is reduced from 12 MiB to 6 MiB.

## iPhone 7 rendering

The V0.3.7/V0.3.8 compatibility path remains. TransferShardView additionally removes trails, per-shard shadows and spring interpolation on the legacy compositor profile while preserving exact checkpoint-driven progress.

Protocol 4 and Schema V8 are unchanged.

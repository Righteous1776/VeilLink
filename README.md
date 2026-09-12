# VeilLink

VeilLink is a GitHub-buildable iOS 15+ prototype for nearby, serverless encrypted
messaging over Bluetooth Low Energy. The UI is Chinese-first and adapts separately
to compact iPhone screens and regular-width iPad layouts.

## Included in V0.1

- SwiftUI phone tab layout and iPad sidebar/detail layout.
- Up to five local cryptographic identities.
- Six-digit app lock with Touch ID / Face ID fallback.
- CoreBluetooth central + peripheral discovery and state restoration.
- Signed identity hello, ephemeral X25519 handshake and six-digit verification.
- ChaCha20-Poly1305 encrypted text packets with replay counters.
- Fragmented BLE GATT transport with flow-aware queues and resumable JPEG / HEIC / PNG transfer.
- SQLite WAL storage with encrypted message bodies.
- Password-encrypted ZIP backup and rollback-first restore path.
- Hidden black-and-gold Owner Mode with expiring, privacy-bounded capabilities.
- GitHub Actions workflows for simulator compilation and unsigned IPA packaging.

The current V0.2 engineering checkpoints additionally add compact binary envelopes,
bounded BLE reassembly/queue memory, persistent outbound resend with authenticated
ACK handling, explicit delivery failure reasons, manual retry, and Protocol 4
receiver-confirmed resumable image transfer. V0.2.2 further tightens runtime stability with
96 KB wire-aligned BLE reassembly budgets, per-source invalid-packet isolation, batched
SQLite maintenance, and self-healing completed-attachment state. Images are split into
authenticated 48 KiB application chunks whose encrypted checkpoints survive disconnects
and app relaunches. The transfer UI now uses checkpoint-driven shard animation: the sender's
local photo fragments as confirmed chunks leave, while the receiver assembles an
encrypted shard field and reveals the real image only after integrity validation.

V0.3 adds local contact aliases and identity deletion, then V0.3.1 adds device-local
message deletion / conversation clearing, persistent pause-resume-cancel controls for
outgoing images, and an opt-in setting to save fully verified received images to Photos.
Protocol 4 is unchanged; the local SQLite schema is V7.
V0.3.4 establishes VeilLink's own visual identity instead of a generic black/gold skin. Identity IDs now derive deterministic local visual glyphs; broad near-black "veil" planes create depth without bright glass effects; asymmetric cut panels replace most generic rounded cards; and motion is constrained to three meanings: Reveal, Transit, and Resolve. Conversation headers, peers, settings, lock/onboarding, transfer surfaces, and iPad navigation share the same language. Protocol 4 and Schema V7 remain unchanged.
V0.3.9 keeps the V0.3.8 iOS 15 layout stabilization and adds a performance overhaul aimed at A10-era devices: normal chat rendering decrypts only a bounded recent window off the main thread, immutable message bodies use a bounded decrypted-text cache, image bubbles use ImageIO downsampled previews with an NSCache instead of full-resolution UIImage decoding, inbound attachment finalization reads/decrypts all persisted chunks with one prepared SQLite statement and one SHA-256 pass, and iPhone 7 uses a lower-cost shard animation path. Protocol 4 and Schema V8 remain unchanged. V0.3.10 then specializes those budgets for the actual deployment devices: SE1, iPhone 7/7 Plus, SE2 and iPhone 13 Pro each receive different message-history, image-cache, BLE-memory, refresh and transfer-rendering budgets. Memory warnings actively release transient caches, A9/A10 devices trim them on background, and the decrypted-message cache evicts incrementally instead of periodically flushing everything. iPad Air 4 remains a tracked experimental target with known UI defects intentionally deferred. V0.3.11 keeps those automatic profiles as the safe default but adds an authenticated Owner Mode performance switchboard: local-only toggles can lift image-preview resolution, attachment-cache, refresh-coalescing and visual-motion limits when explicitly requested, with a deliberately theatrical high-risk preset and a one-tap return to automatic policy.

Multi-hop relay, signed Owner token generation, and full on-device BLE testing
remain for later iterations. Their boundaries are already represented in the
architecture.

## Build entirely on GitHub

1. Create an empty GitHub repository and upload this project.
2. Keep the default branch named `main`.
3. Open **Actions → iOS CI → Run workflow**.
4. The workflow installs XcodeGen, generates `VeilLink.xcodeproj`, resolves the
   package dependency, and compiles against an iOS simulator SDK.
5. Run **Build unsigned IPA** to receive `VeilLink-unsigned.ipa` as an artifact.

The unsigned IPA verifies device compilation but cannot be installed directly on a
normal iPhone. Installation requires an Apple-issued development/distribution
certificate and matching provisioning profile. Never commit certificate, profile,
or private-key files to GitHub; the repository ignores their common extensions.

## Local Mac build, if available later

```sh
brew install xcodegen
xcodegen generate
open VeilLink.xcodeproj
```

## Security status

This is an engineering prototype, not an independently audited cryptographic
product. Do not represent V0.2 as suitable for high-risk communications until the
protocol, key lifecycle, restore path and real-device BLE behavior have been tested
and reviewed.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the protocol boundaries.

## Image import and photo export

VeilLink accepts common image files plus RAW / DNG / ProRAW when the current iOS decoder supports them. Large or RAW inputs are processed off the main thread, capped to 4096 px on the long edge, encoded as high-quality HEIC when available (JPEG fallback), and kept near a 1.8 MB soft target with a 3 MB protocol hard limit. Small JPEG/HEIC files and lossless PNG graphics can be preserved without re-encoding. Received JPEG/HEIC/PNG attachments can be written to Photos through PhotoKit after explicit add-only permission.

V0.3.12 adds an entirely local full-screen image viewer for verified chat attachments. Tapping an image opens a black full-screen canvas with pinch zoom up to 5×, double-tap zoom, panning while zoomed, and swipe-down dismissal at 1×. Chat bubbles keep device-budgeted thumbnails; the viewer performs a separate on-demand ImageIO decode sized for the actual deployment devices (1536 px SE1, 2048 px iPhone 7, 2560 px SE2, 3072 px iPhone 13 Pro / iPad Air 4, or 4096 px only when the Owner Mode high-definition override is explicitly enabled). Source attachment bytes remain encrypted at rest and are never sent anywhere for viewing.


## V0.3.13 BLE reliability

V0.3.13 focuses on real-device reliability for SE1, iPhone 7, SE2 and iPhone 13 Pro. The transport now refreshes/smooths RSSI, paces packet bursts more conservatively as the link becomes marginal, prioritizes handshake/ACK/checkpoint/text traffic ahead of bulk image fragments, reconnects indefinitely with capped backoff while the user still wants the link, and detects stalled send queues. The secure Hello is retried idempotently and pending outbox rows are woken immediately after a trusted session re-authenticates. Messages no longer fail merely because a noisy link passed ten send attempts; the existing persistent outbox expiry is the final bound. This improves eventual delivery but does not claim a guaranteed number of meters, because iOS scheduling, obstruction and 2.4 GHz interference remain physical constraints. Protocol 4 and Schema V8 are unchanged.

## App easter egg

The creator left a hidden easter egg inside VeilLink. Its trigger and contents are intentionally undocumented—explore the app to discover it.

作者在 App 里留下了一个隐藏彩蛋。这里仅确认它存在，触发方式与内容留给你在应用中发现。

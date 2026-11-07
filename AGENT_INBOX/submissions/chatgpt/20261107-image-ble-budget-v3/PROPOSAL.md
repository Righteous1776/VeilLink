# VeilLink Image V3 — all BLE images under strict size budget

## Implemented in PATCH.diff
1. Separate radio budget from protected Wire v4 3MB ceiling. BLE: target 200000 bytes; hard cap 384000 bytes; max dimension 1600. Only *authenticated preferred LAN* receives normal 1.8MB target / 3MB cap.
2. `ImageTranscoder.prepare(at:profile:)` re-encodes files above the applicable soft target, using ImageIO HEIC first, JPEG fallback, downsample 1600/1280/1024/800/640 over BLE, 3 quality attempts per size and size-feedback adjustment with 0.56 quality floor. Stop at the hard budget, not quality-0.2 extreme.
3. Already-small JPEG/HEIC/PNG <= 200KB do not require further lossy re-encoding. All BLE-sent images remain <=384KB (assuming all callers respect the sendImage API).
4. PNG alpha is never intentionally flattened to JPEG: under the limit, keep PNG; over, lossless re-encode and optionally shrink dimensions; if it cannot fit fail with message.
5. ConversationView uses SessionCoordinator.preferredTransportKind, defaults unknown/relay to BLE. SessionCoordinator.sendImage repeats admission check, and its durable attachment sender refuses any image >384000B on *non-LAN* (including BLE) after a link change: defer until high-speed path is back.
6. No WireProtocol v4 format changes, database schema changes, changed MIME, new binary library or release workflow.

### Transport planning
- BLE target 200KB / hard 384KB are provisional and need field tests. 3MB would need ~62 attachment 48KiB chunks while 384KB needs up to ~8 chunks; protocol overhead and real BLE ATT throughput still apply.
- Durable LAN-sized images that fail over to BLE remain queued and will not transfer until authenticated LAN reappears; this should be surfaced to the user in UI.
- Jpegli from #153 can be used as optional standard-JPEG encoder later, but does not obviate BLE byte budgeting.

### Arbiter
V3 **supersedes** duplicate ImageTranscoder edits in #152 / #153 and conflicts with #138 800KiB BLE media limit and MediaTransferPolicyTests. Do not blindly apply all proposals.

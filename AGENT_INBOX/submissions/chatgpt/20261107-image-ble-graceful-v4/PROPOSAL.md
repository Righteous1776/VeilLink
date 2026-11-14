# VL-IMAGE-V4 — Compress first, don't prohibit

**Owner correction:** The prior #154 384KB hard cap/automatic LAN-to-BLE defer policy is too aggressive. **Treat 200KB as soft aim, 384KB as preferred image budget, not a transmission cap.** Any supported image <= existing WireProtocol.maximumImageBytes (3MB) remains sendable over BLE even when slower.

## Candidate implementation
- Based exactly on `main@ccafebab147e069fbabfff579dbf323b0d54f191`. Pull relevant V3 image/UI/policy code as an independent candidate but **intentionally omit all #154 SessionCoordinator guard/defer changes**.
- ImageTranscoder profile (current authenticated .lan => .fastLAN; all else => .bluetooth) biases initial decode size/quality and bounded local compression. BLE recommends 200KB target, 384KB preferred ceiling; quality floor 0.72, no forced 0.56. HEIC preferred, JPEG fallback.
- If no candidate satisfies the preferred BLE range, choose the smallest valid candidate within the existing 3MB wire ceiling and SEND IT (including transparently encoded PNG). Preserve an existing standard JPEG/HEIC/PNG original <=3MB as a safe last fallback. Never reject >384KB by size alone.
- Crucially, do not mutate durable payload after the manifest and SHA-256/attachment checkpoints exist. The existing SessionCoordinator 48KiB chunking, authenticated ACK/checkpoints, retry, transport fallback and .bulk priority continue unchanged; no new wire feature bit or database schema.
- A brief status note indicates when BLE is carrying a larger image with potentially slow progress; existing pause/resume/cancel controls remain unchanged.

## Conflict arbitration
- **Supersede #154**: specifically reject its SessionCoordinator.sendImage profile hard admission and sendAttachmentStep deferral on BLE fallback.
- **Overlaps #138** media transfer policy and #152/#153 image encode experiments. Governor must pick one coherent path before integration. Jpegli vendor work stays an optional independent future stage.
- Larger media via BLE may be much slower; adding bitrate estimators, foreground-only prompts, enhanced congestion pacing are future *measured* optimizations, not invented speed claims.

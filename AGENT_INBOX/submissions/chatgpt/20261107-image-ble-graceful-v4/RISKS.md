# V4 risks, Owner correction and overlap
- Previous #154 would reject/delay BLE image >384KB. Do NOT integrate that. V4 corrects this without modifying SessionCoordinator's existing 3MB protocol gate and durable attachment path.
- 384KB is not a hard cap. Large 0.5–3MB photos may be slow over BLE and consume energy; no throughput guarantees until real-device tests.
- A high compression target can harm fine text; V4 BLE search quality floor raised from V3's 0.56 to 0.72, but some downscaling still occurs. Record visual quality, not only output bytes.
- PNG transparency remains in PNG; downsample itself changes pixels. If no image can fit existing WireProtocol 3MB absolute cap, protocol behavior cannot be bypassed.
- The chosen fallback (smallest sendable candidate) may favor low resolution and can be tuned after quality corpus testing. Never alter image payload after durable manifest / SHA-256 checkpoints are persisted.
- Existing .bulk queue priority does not guarantee fast delivery or prevent all BLE contention; compare with Concurrent Fabric #149/#151 after governance review.
- Conflicts directly with #138, #152, #153 and #154 image policies. This is a replacement, not a stackable delta.
- INBOX_ONLY; no main/product/CI/release/IPA changes. macOS build/device tests NOT_RUN.

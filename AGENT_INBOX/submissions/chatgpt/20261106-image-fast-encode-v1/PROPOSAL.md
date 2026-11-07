# Image Compression Acceleration V1 — Adaptive Bounded Encoder

## Verified main pipeline
- ImageIO already supports HEIC (when destination available), JPEG fallback, and PNG original preservation.
- ImageTranscoder currently tries seven descending qualities ([0.94...0.66]) across as many as six resolution ceilings; in hard-to-compress scenes this can consume up to 42 encodes per codec, even before JPEG fallback.
- Every image has a 3,000,000-byte wire cap and 1,800,000-byte soft goal. SessionCoordinator has 48-KiB encrypted chunks and LAN four-chunk checkpoint window; no protocol update is authorized in this lane.
- The sender is already asynchronous via Task.detached and sends the compressed Data to SessionCoordinator. No new codec MIME types.

## Proposed concrete code changes
1. Replace static quality trial sweep with *actual-size feedback*: start at quality 0.86, derive next quality from sqrt(target/encodedByteCount), use min drop 0.06 and floor 0.62.
2. Limit to **3 encodes per resolution**, 5 resolution ceilings (4096,3072,2560,2048,1600) instead of 6; worst-case 15 encodes per codec, compared with old 42. This is an algorithmic upper bound, not an observed performance benchmark.
3. Stop immediately if under soft budget. Preserve the first good high-resolution encode under 3 MB, even if none reach 1.8 MB. JPEG fallback when preferred HEIC cannot produce a valid result under hard limit.
4. Respect cooperative Task cancellation between dimensions/encodes, preserve ImageIO memory-limited thumbnail decoding and original-file fast path.
5. Add focused XCTest tests for quality feedback, bounds, malformed budgets and no escalation, without modifying WireProtocol v4, media limits, encryption or databases.

## Next independent stage
- #138 proposes BLE vs LAN differentiated media bytes policy. It overlaps `MediaTransferPolicyTests` and needs Governor arbitration; do not modify transport byte caps or route negotiation here.
- Assess HEIC encoder device behavior, actual encoding latency p50/p95, image SSIM/PSNR (or human quality review) and transfer p50/p95 for photographic/scanned/noisy inputs. For BLE, greater throughput still depends on radio constraints and peer path selection.
- No claim of 10x speed, device run, or all large images accepted.

No new third-party image library required. Apple ImageIO thumbnail and destination APIs avoid extra dependencies and preserve existing MIME compatibility.

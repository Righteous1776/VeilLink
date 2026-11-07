# Image V4 — no crude ban, soft compression targets

The owner rejects PR #154's hard BLE 384KB ban, including its LAN->BLE deferral gate. This V4 **replaces #154**, not stacks on it. The existing Wire v4 3MB *protocol* cap remains and is the only allowed image-byte admission limit.

## Proposed source patch
- BLE: 200KB aspiration, 384KB preferred threshold. Neither is a send-blocking limit; valid images of 500KB, 1MB, 2.9MB still send via ordinary E2EE attachment logic.
- Fast LAN: up to current 3MB protocol size, favors fidelity rather than forcing BLE-sized downsampling. The preferred route selects encoder profile before enqueue; no new route permission check.
- Adaptive HEIC/JPEG built into ImageIO: prioritize 0.90 quality for BLE / 0.96 LAN, reduce no lower than 0.78 BLE / 0.84 LAN. Up to 3 attempts per dimension. Low-resolution candidates only replace an existing high-quality fallback when size reduction is >=22% or meets preferred threshold.
- Already-efficient supported originals under preferred budget are unchanged. If compression cannot meet 384KB, retain a valid <=3MB fallback and transfer it. Preserve transparency of PNG when downsampling.
- Durable outbox is IMMUTABLE after queueing: existing SessionCoordinator, 48KiB chunks, SHA/checkpoints, ACKs, control/realtime/bulk queue, and transport fallback are not altered.

## Audit and priorities
- `SessionCoordinator.swift` deliberately absent from this patch, removing the rejection introduced by the previous PR #154 proposal.
- #138, #152, #153, #154 overlap; Governor must choose V4 over #154, not blind cherry-pick all. Jpegli source pin in #153 can be revisited independently.
- Real BLE speed, audio prioritization and image fidelity must be measured on a pair of iPhones. The 200/384KB figures are hypotheses, not benchmarks.

# V0.3.10 Targeted Device Performance

VeilLink 0.3.10-dev build 16 is a device-targeted performance checkpoint. It is cumulative from GitHub main `aadb80b02e2fc4eeab3d4032d392cd37267e82fc`, so Work only needs one patch even if V0.3.8/V0.3.9 were not applied separately.

## Primary deployment matrix

- iPhone SE (1st generation, `iPhone8,4`): most constrained profile; 48-message initial window, 640 px previews, 10 MiB preview cache, 3 MiB outbound attachment cache, smaller BLE queue/reassembly budgets, 180 ms coalescing, minimal single-surface transfer visualization, aggressive background cache trim.
- iPhone 7 / 7 Plus (`iPhone9,x`): legacy compact profile; 72-message initial window, 768 px previews, 16 MiB preview cache, 4 MiB outbound attachment cache, bounded BLE budgets, 140 ms coalescing, static 30-shard path without expensive persistent compositor motion.
- iPhone SE (2nd generation, `iPhone12,8`): balanced modern profile; 120-message window, 1024 px previews, 24 MiB preview cache and full transfer visuals.
- iPhone 13 Pro (`iPhone14,2`): high profile; 180-message window, 1280 px previews, 48 MiB preview cache, larger immutable-text cache and BLE reassembly budget, 60 ms coalescing.
- iPad Air 4 (`iPad13,1` / `iPad13,2`): performance profile exists so memory/transport behavior is deterministic, but its known UI defects are intentionally deferred because it is not a primary deployment target.

## Additional runtime changes

- Decrypted message cache no longer flushes the entire cache when full; it uses a bounded FIFO eviction queue, preventing periodic decrypt storms.
- ImagePreviewCache uses NSCache directly (thread-safe) and is sized per hardware profile.
- Clearing a conversation fetches message IDs only instead of decrypting every message first.
- BLE outbound queue and pre-session reassembly budgets scale down on A9/A10 devices and scale up on iPhone 13 Pro. Protocol limits themselves do not change.
- Memory warnings clear preview, decrypted-text and outbound attachment caches. SE1/iPhone 7 additionally trim these transient caches when backgrounded to reduce jetsam risk.
- SE1 transfer progress replaces thirty independently-composited shard cells with one image surface plus a lightweight grid/progress mask. iPhone 7 keeps the shard motif but uses the legacy static path.

Protocol 4 and Schema V8 are unchanged. iPad Air 4 UI repair is explicitly outside this checkpoint.

# V0.2 Transfer Motion + Stability checkpoint

This checkpoint keeps Protocol 3 and Schema V6 unchanged while hardening the image-transfer presentation path.

- Shard motion gains short gold flight trails and a sharper edge glow. Outgoing failures spring the shards back into the source image and switch to a danger-state border instead of leaving a half-disintegrated photo on screen.
- A completed, validated attachment receives a short convergence pulse before settling into the normal image view.
- `Reduce Motion` still removes shard travel, rotation and flight trails while preserving transfer state and progress.
- Outgoing photos are decoded and pre-sliced into 30 pixel-aligned shard images off the main thread. The animation no longer renders thirty full copies of the source photo and masks each copy on every frame.
- Empty reliable-delivery polling cycles no longer trigger chat UI refreshes.
- High-frequency message-change notifications are coalesced for 75 ms in `AppModel`, reducing repeated conversation/message reloads during attachment checkpoints while keeping UI latency effectively immediate.
- New iOS tests verify that the shard factory creates exactly 30 correctly aligned pieces and rejects images too small to split safely.

No plaintext preview, wire-format change, database migration, or new remote-control capability is introduced in this checkpoint.

# V0.2 Transfer Shards UI checkpoint

This checkpoint adds a progress-driven image transfer animation without changing Protocol 3 payload semantics.

- Outgoing image: the actual local photo is rendered as a deterministic 5×6 shard field. Shards peel away as receiver-confirmed attachment checkpoints advance.
- Incoming image: encrypted gold shards assemble using persisted receive progress. The real JPEG appears only after the existing byte-count + SHA-256 validation promotes the completed attachment.
- The animation is driven by persisted protocol progress rather than a synthetic timer, so reconnect/resume continues from the recovered checkpoint.
- `Reduce Motion` is respected: shard travel/rotation is removed while transfer state remains visible.
- The shard animation is intentionally lightweight (30 views, progress bucketed to shard count) to avoid turning a BLE transfer into a GPU-heavy scene.

No plaintext preview or extra thumbnail is introduced on the wire. Protocol 3 remains unchanged.

# Risks
- BLE 384KB is intentionally aggressive; large details and screenshots will downsample or fail rather than be near-lossless. 200KB is a soft goal, not guarantee.
- Re-encoding can increase CPU cost; record encoding latency vs network time.
- Large transparent PNG might fail because alpha preservation prevents lossy JPEG fallback; this is safer than silent flattening.
- LAN-prepared 3MB images remain queued if only BLE returns; sendImage checks route before queue, sendAttachmentStep checks at dispatch; UI should explicitly explain waiting.
- Protected-surface overlap: #138 SessionCoordinator/MediaTransferPolicy, #152/#153 ImageTranscoder + tests. Governor select/reconcile, do not stack diffs blindly.
- No main modification, no wire/schema/crypto changes, no IPA/workflow/manual dispatch, no Apple iOS build or physical tests executed.

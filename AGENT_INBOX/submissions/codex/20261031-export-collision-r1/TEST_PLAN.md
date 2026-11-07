# Test plan

1. Generate two backup exports during the same millisecond with fixed time/different nonces; verify both URLs and files exist and payloads are independently readable.
2. Repeat for Gomoku and Xiangqi `.vltrain.json` exports; verify both envelopes and checksums.
3. Repeat for Deep Telemetry ZIP exports; verify both archives and manifests.
4. Verify names retain `VeilLink-`, `VeilLink-GomokuLearning-`, `VeilLink-XiangqiLearning-` and `VeilLink-DeepTelemetry-` prefixes plus the previous suffixes.
5. Verify Settings storage maintenance still classifies backup and stale temporary exports correctly.
6. Verify no prior destination is deleted when a later export fails.
7. Run new filename tests, backup safety tests, adaptive-learning tests, diagnostic tests, full XCTest and export UI smoke.

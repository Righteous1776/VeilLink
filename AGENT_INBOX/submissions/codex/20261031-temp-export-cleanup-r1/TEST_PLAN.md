# Test plan

1. Create stale Gomoku and Xiangqi `.vltrain.json` packages in the app temporary root; verify storage scan counts them.
2. Create a stale pre-consent black-box JSON and verify it is counted.
3. Create a stale `VeilLink-Import-<UUID>.jpg` image-picker snapshot and verify it is counted.
4. Run “清理过期临时文件” and verify only the four allow-listed files are removed.
5. Verify a fresh training package remains until it is older than 24 hours.
6. Verify wrong extensions, malformed import UUIDs, non-matching prefixes, nested paths and symlinks are not candidates.
7. Verify the persistent adaptive-learning database and recent game records remain unchanged.
8. Verify Documents backup exports remain controlled only by the separate “已导出的备份” category.
9. Run `VeilStorageMaintenanceTests`, full XCTest and Settings storage-management UI smoke.

# Test plan

1. Select a ZIP from iCloud Drive in Settings, cancel the password sheet, and verify the UUID lease directory is removed immediately.
2. Repeat in onboarding; select a second ZIP before using the first and verify only the latest lease remains.
3. Restore a valid backup and an invalid-password backup; verify the snapshot is removed in both paths and restoration behaviour is unchanged.
4. Simulate a process kill after materialisation. On the next cold launch, verify a lease older than 24 hours is removed, a fresh lease is retained, and the sweep removes at most 64 entries.
5. Place a normal file outside `VeilLink-Import-Staging`, plus symlink-shaped and non-UUID entries inside it; verify none are deleted.
6. Import a chat image from Files and from the camera. Verify both temporary payloads are removed; the Files UUID directory is also removed.
7. Import HTML, board-learning JSON and backup-preflight ZIP files to confirm their existing scoped-copy flows remain functional.
8. Run `VeilImportedFileAccessTests`, `VeilImportStagingLeasePolicyTests`, full XCTest, simulator build and physical iPhone 7 Files-provider smoke.

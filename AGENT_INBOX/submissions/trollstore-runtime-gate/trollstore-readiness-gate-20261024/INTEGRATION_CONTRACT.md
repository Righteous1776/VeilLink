# Integration contract — Governor and PR #53

1. Merge and test PR #53 capability detection under its own protected-surface review, preserving UI/Settings scope.
2. Apply this PATCH.diff separately; both proposed files are new, so no source overlap with PR #53.
3. Map the PR #53 result into `VeilInstallationClass` at the composition root. Do NOT add source markers to network packets, backups, contact identity or cryptographic keys.
4. Explicitly opt-in flags default false; avoid `UserDefaults` persistence for any privilege evidence. A feature may remember user preference, but runtime probe must run again after launch.
5. Backend adapter supplies `capabilityDeclaredInSignedApp` based on its audited signed build, and `probe.status` from allowed OS APIs / real bounded operation; status `verifiedAvailable` cannot be created from UI toggles or untrusted user content.
6. Evaluate immediately before starting each optional enhancement; if denied, execute the current baseline implementation unchanged.
7. On protected-data lock, power/thermal pressure, probe expiry or environment change, cancel/suspend enhanced work and fall back without deleting user data or message state.
8. Keep ordinary development, TestFlight, App Store, TrollStore, Lite and Simulator test results separate. No capability matrix cell is marked supported without real-device observation.

## Future modular adapters
- `highMemoryLocalInference`: separate memory-aware model-loader adapter; baseline A9/A10 remains stable, avoid OOM on iPhone 7.
- `backgroundLinkContinuity`: all standard iOS BLE background constraints still apply; no promise of uninterrupted execution.
- `expandedFileWorkspace`: system document picker and user-selected scope only.
- `extendedLocalDiagnostics`: redacted numerical reports; no secrets or other apps' data.

## Integration prohibitions
Do not merge directly from this Inbox branch. No altered entitlements, plist, signing pipelines, main, A9/A10 governor or CI workflows. Scope conflict with PR #53 must be reviewed even though file paths do not overlap.

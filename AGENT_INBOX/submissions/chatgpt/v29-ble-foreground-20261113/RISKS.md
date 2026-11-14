# Protected surface and unknowns
- This branch changes protected `VeilLink/Transport/BLETransport.swift` and BLE policy/tests **only inside Inbox proposals**. No change to product main, no merge, no dispatch or IPA. Issue #6 requires Owner + Integration Governor explicit permission and iOS CI before any integration.
- Root cause of the eight SE2 retries is unknown. This may address missed reconnection after foreground transitions but is not evidence of fixing underlying GATT, security, firmware or radio failures.
- Foreground `retrievePeripherals` may cost airtime and CPU when refreshLinks is invoked often; verify with Instruments and throttle if needed, without silently erasing wanted intent.
- In `reconnectDisconnectedOnly` mode, already connected peers intentionally do not rediscover GATT. Stale secure session is still managed by security watchdog; don't advertise secure-ready until authenticated.
- Concurrent status/event logic in BLETransport is unchanged, but full iOS15 Bluetooth dual-device regression is mandatory. Weak-link retries must not be accelerated indefinitely.
- The new proposal does not modify PR #192 (blackbox), PR #194 (native llama) or PR #195 (optional chat input). Governor must arbitrate all protected lanes; do not silently merge.

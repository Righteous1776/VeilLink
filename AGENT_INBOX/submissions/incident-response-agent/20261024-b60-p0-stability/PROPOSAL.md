# Evidence-driven stabilization proposal

The four owner-supplied DeepTelemetry ZIPs were analyzed locally, not uploaded. They report VeilLink 26.14 Build 60, while current main is 26.15 Build 61. The iPhone 7 (iOS 15.8.3) trace reports one existing conversation, SQLite integrity OK, and a strong GATT_READY BLE link. This **does not** establish that the separate Keychain-missing screen is resolved.

1. The global particle modifier registers a root-level simultaneous DragGesture. Canvas allowsHitTesting(false) does not prevent this gesture from competing with Slider/game drag/scroll actions. Drop the root gesture and cap bursts/ambient effects; respect Reduced Motion and serious thermal states even in forced effects mode.
2. iPhone 7 had 18 failed `a9.refresh` checks in an 18-cycle extreme stress report. Its A10 independent mode deliberately disables A9 evaluation, while the stress harness incorrectly requires A9 timestamp advancement. Make the assertion mode-aware and still require A10 sample progress.
3. AppBootstrap initialization failure after legal acceptance shows StartupFailureView with no working diagnostics export. Add a fixed-event `startupFailed` record and make isolated pre-consent black-box export available there, without constructing AppModel or exporting private error text.
4. Standard runtime-context lacks installation channel/capability state. Include the existing `VeilRuntimeEnvironment.current.diagnosticsReport` for future TrollStore/ordinary signer correlation; do not claim extra permissions from marker presence.

High-risk issues deliberately **not** automatically modified: storage key / Keychain group continuity, SQLite v10 migration, Wire v4 crypto and elevated entitlements. Re-signing can change Keychain access group, resulting in `errSecItemNotFound` even when old data remains; never invent a replacement key. iPhone7's 61 collaborative session-mismatch warnings (bulkReady dominated), remote-ready timeouts and a session error require separate paired transport diagnosis.

This is a proposed diff only. No real-device verification, no Xcode compilation, no release or IPA action was run.

# V30 VeilScreen lifecycle / privacy gate

These findings were identified in the staged product code at `e50892f`.

## Fixed in this isolated hardening branch
- The sender consent sheet must not turn blank after first READY-ACK. It dismisses once genuinely LIVE, while the independent app-owned capture host/pump stays alive.
- `synchronize()` no longer publishes identical snapshots every 1-second tick, avoiding unnecessary SwiftUI chat relayout.
- The ReplayKit broadcast extension can be terminated from the iOS system interface. The sender checks that the encrypted App Group session still exists after actual capture started, then sends a STOP/revocation, clears buffers and ends LIVE; avoids a phantom session.
- Identity switch, backup restore/suspension and explicit trust revocation terminate the live screen capture **before** the BLE secure session is reset.
- The session-machine XCTest checks `captureRevoked` ends and rejects stale callbacks.

## Nonclaims / stop-ship
- No Xcode/simulator/device compile test has been run for this branch.
- iOS background host suspension can stop screen transmission; TrollStore does not prove 100% continuity.
- No user-specific signing profiles or app-group entitlements are available to verify here.
- Never publish a V30 IPA as having real screen sharing before a signed two-device test actually exchanges encrypted frames.

The upstream V30 source branch can incorporate this after review. No PR or duplicate Action is triggered by this staging branch.

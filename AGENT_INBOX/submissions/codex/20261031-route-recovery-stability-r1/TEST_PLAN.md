# Test plan — route recovery stability R1

## Executed here

- `git diff --check` on the isolated candidate: PASS.
- Static review confirms deliberate `stopLocked` clears listener/browser before calling `cancel()`, while handlers retain the existing identity guard.
- Static review confirms unexpected `.cancelled` events clear the active slot and call the existing bounded listener/browser recovery scheduler only while `running`.
- Static review confirms `sendRequests` contains no direct `markFailure` call and `postJSON` remains the single POST failure-accounting owner.
- Added XCTest coverage that one failure preserves a reachable provider and the second consecutive failure crosses the threshold.
- Replayed `PATCH.diff` against a fresh checkout of the recorded baseline and compared the resulting product diff byte-for-byte: PASS.

The current execution image is Linux and has no `swift`, `xcodegen` or `xcodebuild`; no Apple compilation or XCTest execution result is claimed.

## Required Governor/device gates

1. Replay `PATCH.diff` at the recorded baseline with strict context.
2. Run XcodeGen, iOS 15 build and complete XCTest, including `InternetRelayTests` and `LANTransportTests`.
3. On two physical devices, start LAN Turbo, cycle Wi-Fi off/on and between access points/hotspots, then verify listener and discovery recover without app restart.
4. Stop LAN Turbo deliberately and wait beyond every recovery delay; verify no listener/browser restarts.
5. Inject one relay push timeout while a provider is reachable; verify it remains eligible and the pending SessionCoordinator outbox retries.
6. Inject two consecutive relay push failures; verify that provider becomes unavailable, then verify a successful probe restores it.
7. With smart dual mode, fail one and then both providers; verify each request contributes at most one failure per provider and duplicate delivery protection remains intact.
8. Re-run P0 signing, chat delivery, ACK/retry, foreground/background and local-network permission regressions.

Any deliberate-stop resurrection, unbounded recovery loop, duplicate failure count, duplicate message or lost ACK blocks integration.

# Test and verification plan

## Static tests
- `VeilTrollStoreReadinessGateTests`: ordinary/simulator/unknown default fallback; TrollStore/Lite candidate; explicit user opt-in; signed declaration; probe missing/negative/unverified; 600-second expiry and future timestamp; protected-data lock; foreground policy; legacy iPhone7; thermal/low-power; NaN/Infinity.
- No imports of Security, private frameworks, substrate, jailbreak APIs or a TrollStore executable/marker reader.
- `git apply --check`, `git diff --check`, XcodeGen source inclusion, iOS 15 XCTest, full app regression.

## Physical matrix (only if user owns/authorizes those test devices)
- iPhone7 iOS15 standard signed => standard mode; ordinary iOS26 iPhone => standard mode.
- Supported system with genuine TrollStore and TrollStore Lite => candidate only before declaration/probe.
- Missing/invalid entitlement or denied probe => silent standard fallback, no crash.
- Fresh valid probe + enabled + signed capability => policy returns candidate; per-feature OS operation still verifies authorization.
- App background, protected-data lock, thermal warning, Low Power Mode => low-risk fallbacks.
- Login, Keychain, BLE, chat, attachments, DB integrity and backup/restore behave identically in all distribution variants.

## Claims
Policy logic ready for static review; native Xcode/iPhone runs have NOT been performed. This adds no active elevated capability.

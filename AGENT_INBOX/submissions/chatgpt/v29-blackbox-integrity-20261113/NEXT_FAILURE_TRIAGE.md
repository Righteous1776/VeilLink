# V29 remaining incidents (NOT FIXED by this drop)

## P0 crash / hang
Need exact V29 Build66 unsigned IPA Mach-O UUID + dSYM for symbolication. MetricKit collected 6 payloads on iPhone7, 3 on SE2; only SE2 separately reported 3 BadAccess exits on Nov8. A 7,849ms hang bucket and 880,273kB peak were observed. No direct crash stack attribution exists; changes to arbitrary memory managers would be guesswork. Host should repro on iOS15 without deleting app data, and run Instruments Allocations, Memory Graph, Time Profiler.

## P0 BLE secure-session recovery
V29 main did not directly change Transport/Security compared to V28. Live Veilopoly invite only proceeds when `hasSecureSession` is true; sending needs authenticated peer and control capability bit1. A physical "connected" indicator is insufficient. SessionCodec failure stage cannot be identified from exported runtime records. Cross-device controlled capture should record monotonic clock and sanitized stage labels: scan, BLE connection, GATT subscribed, hello verified, secureReady, capabilityMask, control accepted, invite recv/accept, room snapshot acknowledged. No plaintext fallback, no blind retry-policy edits. Issue #185 owns the protected lane.

## P2 swipe metadata
The observed zero displacement on many swipe events cannot be safely mapped to a touch handling failure; current `PassiveTouchRecorder` computes displacement using UITouch positions, so first reproduce with rawTouchCapture owner opt-in and view-hit-testing context before rewriting gesture code. Never record typed content or enable raw touch by default.

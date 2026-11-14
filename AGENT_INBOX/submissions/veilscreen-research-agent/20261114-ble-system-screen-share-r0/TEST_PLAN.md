# Test plan

**Completed, not device proof:** Swift 6.2.1 Linux: protocol control encode/decode, reverse-ordered chunk reassembly, replay suppression, adaptive budget, frame digest passed. Advisory diff add-file patch checked in a clean copy of earlier VeilLink source.

**NOT RUN:** Apple ScreenCaptureKit iOS26 SDK signatures; XCTest from FILES/VeilScreenShareWireTests.swift; arm64 iPhoneOS Release; two-phone BLE throughput under 1/3/6/12 KiB/s, no Wi-Fi; foreground -> sender background -> receiver background -> reopen; consent revocation; rotation; device lock/calls; battery/thermal 10/30-minute; log audit/no data persistence. Before integration fuzz malformed chunks, replay, wrong session, disconnections, key rotation, UInt32 wrap, expired invite and queue congestion. No IPA produced.

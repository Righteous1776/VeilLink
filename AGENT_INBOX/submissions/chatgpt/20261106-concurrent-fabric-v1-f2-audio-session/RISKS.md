# F2 integration risks
- **Exact-file overlap** with F1 #149 in `VeilLink/Voice/WalkieTalkieAudioController.swift` (finishReceiving). Governor arbitration required.
- **Behavioral overlap** with #146 CoreBluetooth audio-route-change monitoring; iOS audio session and BLE still use shared RF resources.
- Exclusive audio owner may reject overlapping voice requests instead of preempting. This is a safety improvement but can change user experience; status/UX and retry behavior require validation.
- iOS interruptions, AVAudioSession route changes, app termination before release, HFP/A2DP sample-rate changes not fully handled by this phase.
- Swift concurrency, Xcode, XCTest, headset real-device outcomes NOT_RUN. No code directly applied to product source, no main/CI/IPA/release.

# R17.2 implementation risks
- iPhone SwiftUI full typecheck and real FPS/thermal testing are **not available** on Linux. Must validate in Xcode and on iPhone 13/iPad; no claims of production readiness.
- Review view hierarchy under iPhone 375–390pt width for chip truncation and offscreen animation CPU cost. SwiftUI `TimelineView` runs only at low, low-power-aware cadence during a search.
- Last search node limit snapshotted pre-await; if future engine budget semantics change, update this readout or hide ratio rather than display misleading measurements.
- Infinite/untimed search still bounded by node/depth and should be canceled when game ends. Verify life cycle on device.
- Search branch `VeilEclipseBoardThoughtField` may be privacy-sensitive; it remains user-opt-in in Training as before.
- UI pulse event requires main runloop handoff to render collapsed/expanded states; verify against rapid repeated moves and Reduce Motion.
- INBOX-only: main, games other than offline Gomoku, training weights, BLE, IPA and version code were not changed.

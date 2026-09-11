# VeilLink V0.2 BLE Reliability Checkpoint

This checkpoint closes the low-MTU / large-payload transport boundary without broadening into unrelated UI work.

## Completed in this checkpoint

- Added preflight fragmentation planning before allocating thousands of BLE packets.
- Supports the full UInt16 fragment range (up to 65,535 fragments) instead of the previous 16,384-fragment application cap.
- Distinguishes temporary queue backpressure from a payload that is physically too large for the negotiated ATT write size; unsupported payloads are failed instead of retried indefinitely.
- Caps outbound queues by both packet count and encoded bytes per peer.
- Caps receive-side partial-message memory globally and evicts older incomplete assemblies when necessary.
- Added boundary tests for the UInt16 limit, low-MTU image-class payloads, and receive-buffer eviction.

## Verification performed here

- `swiftc -typecheck VeilLink/Transport/BLEFramer.swift`
- `swiftc -parse` across every Swift source/test file.
- `git diff --check`.
- Executed a standalone BLE boundary harness covering the 65,535-fragment limit, 30/31-byte ATT threshold for a 1.07 MB envelope, and global partial-buffer eviction/reassembly.

Full iOS build/tests still require the macOS/Xcode CI environment.

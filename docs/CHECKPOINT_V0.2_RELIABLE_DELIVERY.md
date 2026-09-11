# VeilLink V0.2 Reliable Delivery Checkpoint

This checkpoint hardens the persistent outbound lifecycle without changing the Protocol 2 wire format.

## Completed

- ACK retry budget counts only packets accepted by BLE transport.
- Temporary transport backpressure defers a packet without consuming its ACK retry budget.
- Accepted sends use bounded exponential ACK retry delays: 4, 8, 16, 32, then 60 seconds.
- Ten accepted transmissions without a valid authenticated ACK mark the message failed instead of retrying indefinitely while connected.
- The persistent outbound queue remains the source of truth across disconnects and app/database reopen.
- Existing trusted-session reconnect automatically resumes due outbound messages after the handshake completes.
- Failure reason is stored as non-content operational metadata in `messages.delivery_error` (schema migration V5).
- Permanent local failures now distinguish missing/corrupt attachment, invalid content, envelope-size rejection, link MTU rejection, ACK exhaustion, and seven-day expiry.
- Failed outgoing messages expose a one-tap retry action. Manual retry resets retry count and seven-day expiry, clears the failure reason, and re-enters the persistent queue.
- Late authenticated ACKs can still promote a previously failed message to delivered because delivery acknowledgement remains peer-scoped and message-ID bound.

## Regression coverage added

- Temporary deferral does not consume ACK retry budget.
- Accepted transport send increments ACK retry budget.
- Failure reason survives database reads.
- Manual restart clears retry budget and failure reason.
- Outbound queue survives database close/reopen with the same Keychain-backed storage key.

## Verification performed in this environment

- All Swift app and test sources pass `swiftc -parse` with Swift 6.2.1.
- Stale `recordOutboundAttempt` call sites are absent.
- New `delivery_error` read/write/migration paths are internally consistent.

## Remaining device/CI verification

A macOS/iOS SDK runner still needs to execute the XCTest suite and a full `xcodebuild`, followed by two-device BLE tests covering deliberate ACK loss and disconnect/reconnect during a queued image transfer.

# Proposal — repair LAN infrastructure cancellation and relay failure accounting

## Evidence

`LANTransport` only repaired `.failed` listener/browser states. An active `NWListener` or `NWBrowser` that reached `.cancelled` while the transport was still running retained its slot and could no longer be rebuilt by refresh or scheduled recovery. A deliberate stop is distinguishable because `stopLocked` clears the stored object before cancelling it, and the existing identity guard rejects that callback.

`InternetRelayTransport.postJSON` already records provider failure for every unsuccessful POST. `sendRequests` recorded the same outcome again in both single-provider and dual-provider failure paths. Because the provider threshold is two, one transient push failure could immediately mark a reachable route unavailable.

## Corrections

### LAN listener and discovery recovery

When an active listener or browser reports `.cancelled`, the candidate clears only that active slot, publishes a recovery status and enters the existing bounded retry scheduler. User-initiated stop remains terminal because the stored object is cleared before `cancel()` and therefore fails the handler's identity guard.

### Relay health accounting

`postJSON` remains the single owner of HTTP POST success/failure accounting. `sendRequests` awaits its results without incrementing failure counts a second time. The threshold mutation is extracted into `VeilRelayProviderHealthPolicy` and covered for first- and second-failure behavior.

## Compatibility boundary

- No wire protocol, encryption, persistence, sequence, ACK or retry-budget change.
- No BLE file is edited; open PR #97's BLE handshake recovery remains complementary and conflict-free at file level.
- No endpoint, timeout, provider selection order or user setting changes.
- Existing bounded LAN recovery delays and maximum attempts are reused.

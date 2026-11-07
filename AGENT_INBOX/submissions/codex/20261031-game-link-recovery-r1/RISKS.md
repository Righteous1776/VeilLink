# Risks

- Never write a game command before authentication merely to make the UI appear responsive; that would create a false local board state.
- Recovery operations must remain idempotent. This proposal uses existing refresh APIs and does not tear down healthy connections.
- Automatic resend of a user's tap is intentionally not introduced because VLGM1 has no causal parent pointer; explicit retry avoids duplicate invitations or moves.
- The relay refresh is a no-op when relay is disabled or stopped, and LAN refresh preserves healthy listener/browser infrastructure.
- Telemetry must not contain peer identity, message contents or moves.
- The patch must be applied and tested with current transport code on a Mac/two-device lane before promotion.

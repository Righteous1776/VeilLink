# VeilLink 28.0 · Build 65

Owner-authorized major integration release. This document describes the candidate;
publication status is established only by passing CI and the GitHub release assets.

## Veilopoly now in the real game hall

- Offline fullscreen landscape game, native AI, property/auction/trade/bank/settlement actions.
- Simulated local five-instrument market, replayable randomness, banking safeguards and saved-game restore.
- Unified ivory/teal/gold UI using actual Astra/Kimi/generated runtime assets, with programmatic financial values.
- Quiet single-line city news: real committed income/rent/transactions/market events and varied local city vignettes, bounded/debounced and pausable.
- Offline card/street/company/rulebook text. Shipping gate verifies all 99 PNG, 13 WAV and dice XML in both the built app and IPA against source hashes.

## Inbox convergence

Current-base fixes cover background diagnostic logging/telemetry damping, reconnect stability,
chat bottom/follow behavior and invitation gestures, equal-timestamp insertion order,
safe bounded Files draft/image import and lease cleanup, nonblocking soft-budget image preparation,
startup signposts/deferred full integrity audit, audio-session ownership/headset coexistence,
multi-transport session recovery, legal IME commit timing, export-name collision prevention,
and durable Gomoku/Xiangqi games with selectable seats.

Owner clarified that game advice must remain and work: compact devices can now request
native legal recommendations on demand, preserving opt-in manual execution and fresh-board validation.
Native Gomoku Bot-vs-Bot training has its own detailed per-move export; the ordinary training export stays separate.

The optional original opponent UI keeps its native fallback. PR #160 does not contain the
referenced MP4/GIF binaries; unavailable footage is not claimed as bundled. Generic PDF/ZIP
peer transfer is not added to Wire v4; Files text imports become a draft for user confirmation.

## Compatibility and limitations

iOS 15 minimum; no Wire v4 framing, Relay pairing, SQLite schema, identity/key or M5
shadow/cutover changes. Existing Core heavy-model exclusions and payload budgets stay enforced.
IPA is **unsigned**, following the established repository distribution policy; installation
requires the Owner's existing compatible signing/installation method. No App Store submission
or signing certificate is implied. Simulator/package checks do not certify physical BLE,
headset interoperability, battery use, thermal behavior or on-device visual acceptance.

Full intake decisions and evidence: `docs/engineering/V28_INTEGRATION_PLAN_20261107.md`.

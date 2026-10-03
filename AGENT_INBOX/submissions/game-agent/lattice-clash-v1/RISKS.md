# Risks

## Protected surfaces

No protected surface is modified by the proposed patch. Any future request to add multiplayer, persistence, protocol messages, release changes or A9/A10 coupling must be a separate Governor-authorized task.

## Cross-agent overlap

No direct file-path or LatticeClash symbol overlap was found on current main at preparation time. The lab UI is behaviorally adjacent to other game experimentation, including the staged Orbit Relay proposal, but it does not edit the same files.

If another submission later proposes a shared Game Lab entry or navigation shell, the Integration Governor must decide placement. This agent does not resolve that overlap.

## Behavioral risks

The three-neighbor conversion threshold and two-anchor opening may produce first-player or edge-position bias. Determinism guarantees reproducibility, not balance.

Mitigation: run mirrored bot-vs-bot opening corpus before any user-facing integration; adjust constants only in a later reviewed proposal if bias is material.

## Migration / compatibility risks

None in this proposal because the game is not added to MiniGameKind, protocol payloads, persistence or replay formats. A future promotion to network play would require explicit compatibility design.

## Performance / battery risks

The bot uses bounded shallow search and a 49-cell board. Cost should be small, but synchronous search still runs on the UI action path in the proposed lab view.

Mitigation: profile worst-case midgame branching on iPhone 7-class hardware during integration. If latency is excessive, move search off the main actor or reduce search depth in a separate reviewed change rather than hiding stalls.

## Security / privacy risks

The proposal uses no network, storage, user identifiers, message content, microphone, camera, location, model weights or telemetry.

## Rollback strategy

All three proposed files are additive. Rollback is deletion of those files plus any separate integration wiring the Governor may have added. No migration or compatibility cleanup is required.

## Validation limitation

The pure Foundation rule core was syntax-compiled with Swift 6.2 during proposal preparation and a small harness verified initial legal moves, deterministic bot legality and a three-side capture case. The SwiftUI file still requires repository/iOS toolchain validation after Governor application; no product CI was manually dispatched by this agent.
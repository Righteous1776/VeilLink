# Risks

## Protected surfaces

None are proposed. Any later networking, persistence, Game enum integration, release work or A9/A10 coupling must be a separate Governor-authorized task.

## Cross-agent overlap

No direct proposed file or AfterglowConvoy symbol overlap was found on current main at preparation time.

Behavioral adjacency exists with:
- existing Arcade/Game Lab UI;
- staged Game Agent proposals;
- staged skeuomorphic/render-performance policy proposals.

This task intentionally does not edit shared entry points or consume unaccepted staged APIs. If the Governor later batches multiple game/render proposals, it decides the common navigation and performance-policy integration.

## Behavioral risks

### Emotional tone can become decorative

If the story lines do not affect player decisions, the “companion beacon” could feel like a renamed health bar.

Mitigation: beacon brightness, shield choice, storm response and restoration pickups all directly influence survival feedback. Future playtesting should evaluate whether players change behavior to protect the beacon.

### Difficulty may be seed-biased

Some deterministic hazard seeds may create unusually easy or punishing paths.

Mitigation: run a seed corpus with simple steering policies, compare completion/resource distributions and bound outlier layouts before product promotion.

## Rendering risks

### SpriteKit is a new rendering stack for VeilLink

The current game UI is mainly SwiftUI Canvas. Introducing SpriteKit increases architectural surface.

Mitigation: isolate it to new files and one lab wrapper; do not replace existing arcade rendering.

### Runtime-generated textures

Small glow/rain textures are generated in memory. This avoids app assets but still consumes transient memory.

Mitigation: create once per scene, reuse textures, and keep dimensions tiny/bounded.

### Frame-rate / thermal pressure

Dense rain, fog and particle bursts can hurt iPhone 7-class devices.

Mitigation: explicit constrained tier; cap fixed-step catch-up; bounded nearby hazards; limited transient nodes; integration profiling required.

## Migration / compatibility risks

None at protocol/schema level because the title is local-only and not registered in MiniGameKind.

If promoted to multiplayer later, deterministic input-stream/replay design must be specified separately rather than reusing local scene callbacks as a protocol.

## Security / privacy risks

No network, storage, microphone, camera, precise location, account identity, message content, model weights or user telemetry is used.

## Rollback strategy

All four proposed files are additive. Rollback is deletion of those files and any separate Governor-added navigation hook. No database/protocol migration is needed.

## Validation limitation

The pure Foundation core compiled and passed a local deterministic harness under Swift 6.2.1. SpriteKit/SwiftUI code cannot be validated by the Linux scratch compiler and still requires Xcode/iOS integration-time compilation. No product workflow was manually dispatched by this agent.

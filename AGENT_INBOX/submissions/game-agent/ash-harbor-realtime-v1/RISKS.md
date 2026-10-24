# Risks

## Protected surfaces

None are modified by the proposed patch. Any future package dependency, navigation registration, protocol, persistence, release or A9/A10 integration must be separately reviewed.

## Cross-agent overlap

No direct `AshHarbor*` file or symbol overlap was found on current main.

Behavioral adjacency exists with:

- existing/staged Game Lab work;
- the staged skeuomorphic/render performance budget proposal;
- any future shared navigation/game-launch surface.

This agent does not resolve those overlaps. The Integration Governor decides common entry points and render-budget policy.

## Open-source licensing risks

### MIT / Apache code

Permissive does not mean “license disappears.” If code is vendored from ShaderKit or another MIT/Apache project, required copyright/license notices must ship with the product.

V1 avoids this risk by not copying third-party code.

### Mixed-license sample art

Some open-source repositories use permissive code but include demo artwork under different licenses.

Mitigation: never copy sample art merely because the code repo is MIT. Asset license must be checked separately.

### CC0 provenance

Kenney and Poly Haven assets are appropriate candidates because their official sources state CC0. Still record original source and asset identity during integration so provenance remains auditable.

## Behavioral risks

### Rescue pacing

If slowing down for rescue is always optimal or always impossible, the tension collapses.

Mitigation: tune hold durations / route timer using bot or scripted policy simulations and human playtests.

### Emotional layer may feel artificial

Radio text can feel manipulative if overused.

Mitigation: short lines, no constant chatter, and let mechanics carry most of the emotion. Rescue success changes the ending tone but does not force a melodramatic cutscene.

## Rendering risks

### Water shader compatibility

SpriteKit shader compilation can fail on device even when Swift source parses.

Mitigation: integration-time simulator + iPhone 7 device shader compilation. Provide non-shader fallback water node if necessary.

### Thermal / battery load

Rain, fog, shader, searchlight and particle spray can compound GPU cost.

Mitigation: constrained tier, bounded emitters/nodes, real-device profiling, and integration with the accepted performance-budget policy if Governor chooses.

## Migration / compatibility risks

None at protocol/schema level because Ash Harbor is local-only and not registered in MiniGameKind.

## Security / privacy risks

No network, storage, microphone, camera, precise location, account identity, messages, model weights or user telemetry are used.

## Rollback strategy

All four proposed product/test files are additive. Rollback is deletion plus removal of any separate Governor-added navigation hook. No migration cleanup is required.

## Validation limitation

The Foundation core compiled and passed a deterministic harness under Swift 6.2.1. SpriteKit/SwiftUI files passed parser validation only; full semantic iOS compilation is still required.

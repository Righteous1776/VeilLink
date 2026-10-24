# Risks

## Protected surfaces

No protected surface is modified.

## Cross-agent overlap

No direct BlackoutDistrict file/symbol overlap found on current main at preparation time.

Shared Game Lab navigation and common render-policy integration remain Governor-owned.

## Third-party risks

### ShaderKit

Direct code use is now intentional.

Risk:
- shader files must be copied into the app bundle;
- MIT notice must remain.

Mitigation:
- exact upstream revision recorded;
- license vendored;
- integration test verifies Bundle lookup.

### Kenney CC0 city art

Risk:
- adding entire packs wastes bundle size and creates visual inconsistency.

Mitigation:
- direct-use permission is accepted, but only curated derivatives are imported;
- fixed resource aliases are defined;
- full source packs remain outside product bundle.

## Simulation risks

### Cascade balance

A capacity model that is too harsh can create unavoidable collapse.

Mitigation:
- representative seed corpus;
- measure first-fault time, fault count and stabilized-run completion.

### Repair loop repetition

Nine substations can become “drive, hold, repeat.”

Mitigation:
- puddle route choice;
- critical-node priorities;
- graph connectivity makes repair order meaningful;
- later levels may add temporary rerouting/switching rather than more repair bars.

## Rendering risks

- Bloom + rain + full-screen noise + many windows is GPU-heavy.
- optional third-party sprites may have inconsistent scale/palette.
- camera/world scaling needs real-device validation.

Owner direction explicitly removes iPhone 7 performance as a design ceiling; still reject catastrophic thermal or frame-pacing behavior on target modern devices.

## Security/privacy

No network, microphone, camera, precise location, user identity, chat content, telemetry or model weights.

## Rollback

All proposed product/test/third-party files are additive. Rollback is deletion plus removal of any separate Governor-added navigation or asset resources.

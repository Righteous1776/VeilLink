# Remove Global Particle Effects (R1)

## User direction
Remove the **global** particle effects from VeilLink. This includes idle ambient particles, lifecycle celebratory bursts, and the root SwiftUI particle overlay. Localized feature effects (games, animations inside pages, progress/transfer visualizations) remain unchanged.

## Root cause verified at main af3d823546c288169d19cb3033a6111977d28bd7
- `VeilLink/App/VeilLinkApp.swift`: RootContainer attaches `.veilAdaptiveParticles(eventToken:particleEventToken, overrideSnapshot:performanceOverrides.snapshot)` after its main ZStack.
- `VeilLink/UI/VeilAdaptiveParticleLayer.swift`: that modifier builds an animated Canvas with ambient/trail/burst drawing.
- `VeilLink/Core/VeilParticlePerformancePolicy.swift`: independent performance and seed policy used by the global particle system.
- `VeilLinkTests/VeilParticlePerformancePolicyTests.swift`: tests for the removed global feature only.

## Proposed implementation
1. Remove the root-level `.veilAdaptiveParticles` call. This is the critical behavior removal for all root states, independent of God Mode, performance, power, or Reduce Motion settings.
2. Remove the now-unused `performanceOverrides` observer/initializer assignment and `particleEventToken` property inside RootContainer.
3. Delete the global particle modifier/Canvas, its dedicated budget policy and dedicated tests, leaving no feature implementation to re-enable accidentally.
4. Preserve `VeilAmbientBackground` (static gradient/curtains), existing material/scene transitions, `DeviceStressTestHUD`, the app-wide `PerformanceOverrideController` outside RootContainer, and all local game effects.

## Exclusions
No changes to messages/keyboard, message ordering, Bluetooth, storage, legal gate, app version, assets, release pipeline, unrelated animations or gameplay. The user did not request a total animation disable.

## Validation
Static source comparison and exact-base patch generation PASS: 415 -> 406 lines in app root, deleted files 3, total diff paths 4. iOS compile/XCTest/device tests NOT_RUN. See TEST_PLAN.md.

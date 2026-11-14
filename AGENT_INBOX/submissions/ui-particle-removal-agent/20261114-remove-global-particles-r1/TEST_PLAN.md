# Verification Plan

## Static preflight
1. Pin checkout to main af3d823546c288169d19cb3033a6111977d28bd7 (or rebase/reconstruct patch against newer main before applying).
2. `git apply --check PATCH.diff`, then `git apply PATCH.diff` on an isolated integration branch.
3. `rg 'veilAdaptiveParticles|VeilAdaptiveParticle|VeilParticlePerformancePolicy|VeilParticleSeed|particleEventToken' VeilLink VeilLinkTests` must return no symbol references.
4. Verify no changes to `project.yml`, Info.plist, resource manifests, release/version, and workflows.

## Apple build / functional checks
5. Run XcodeGen, iOS simulator Debug compile, all XCTest/UI smoke, and iPhoneOS Release compile on exact integration SHA; the deleted test must be absent from the suite, not a link error.
6. On iPhone and iPad test cold start -> consent -> onboarding -> lock -> chats -> nearby -> settings -> game lobby -> foreground/background. Global ambient drifting particles and lifecycle bursts must never be visible.
7. Test God Mode / forceFullVisualEffects toggle: no global particles return. Other performance overrides must remain operational.
8. Test touch/drag over conversation List, slider, game board, and page back gesture. Existing input hit-testing should be unaffected.
9. Confirm gradients, glass materials, local game graphics and transfer animations are still present; no accessibility/Reduce Motion regression.

## Coverage state
- Exact-source modifier isolation: PASS (checked against main SHA).
- Unified diff structure and deleted-file counts: PASS (generated from exact source strings).
- macOS iOS simulator/XCTest/device/IPA: NOT_RUN (not available in proposal stage).

# Test Plan

## Static checks

- Patch must apply to base main c81f266e0032a1d0868cb25ddc26b690ddea4e43.
- Proposed product changes are limited to two new files:
  - VeilLink/Core/SkeuomorphicPerformanceBudget.swift
  - VeilLinkTests/SkeuomorphicPerformanceBudgetTests.swift
- No existing file is edited.
- No workflow/project/version/protocol/schema/identity/A9/A10/release file changes.
- All budget/result enums and structs are Equatable and Sendable.

## Unit tests

Eight deterministic XCTest cases are proposed.

1. Legacy balanced Tool Panel
   - efficient tier;
   - one shadow;
   - radius 4;
   - no backdrop material;
   - transient tilt limited to 2.2 degrees.

2. Minimal visual complexity
   - essential tier;
   - zero outer shadows;
   - no specular gradient;
   - no tilt or continuous animation.

3. Modern full Tool Panel
   - full tier;
   - two shadows;
   - radius 12;
   - backdrop material and animated glow allowed;
   - tilt 6 degrees;
   - two continuous-animation slots.

4. Runtime constrained
   - full-capability device falls to essential in automatic mode;
   - explicit full-visual override can restore full transient visuals;
   - persistent animation remains disabled unless separately allowed.

5. Reduce Motion
   - static full-tier material hierarchy remains;
   - 3D tilt, animated glow and continuous animation become disabled.

6. Dense Scroll cap
   - full device still caps shadow radius to 4;
   - backdrop and animated glow disabled;
   - continuous animation slots zero;
   - detail density reduced.

7. Arcade Console cap
   - shadow radius <= 8;
   - tilt <= 4 degrees;
   - one continuous-animation slot maximum.

8. Tactical Map cap
   - no backdrop material;
   - no animated glow;
   - no 3D tilt;
   - zero continuous decorative animations;
   - gauge detail capped at 8.

## Integration tests

If accepted and consumed by PR #10 or a later UI batch:

- Tool Center dense search/results scroll uses denseScroll budget.
- Individual tool detail panels use toolPanel budget.
- Artillery, Light Trail and Magnetic Hockey use arcadeConsole budget.
- TacticalLandscapeShellV2 uses tacticalMap budget.
- verify low-power toggle causes budget reduction without navigation restart;
- verify thermal serious/critical reduces to essential;
- verify Reduce Motion removes spatial effects;
- verify God-mode overrides only the intended gates.

## Negative / failure cases

- legacy compositor + balanced profile;
- minimal profile;
- full profile under thermal pressure;
- full profile under low-power mode;
- Reduce Motion with persistent-animation permission;
- full-visual override without persistent-animation permission;
- role caps applied to a full-tier budget.

## Regression invariants

- DevicePerformancePolicy classifications remain unchanged.
- RenderCompatibilityPolicy remains unchanged.
- PerformanceOverridePolicy semantics remain unchanged.
- VeilMotionPolicy remains unchanged until integration deliberately consumes the new policy.
- Transport/cache/game compute budgets remain unaffected.

## Device / OS coverage

Governor integration should validate at least:

- iPhone SE 1 profile / iOS 15;
- iPhone 7 profile / iOS 15;
- iPhone SE 2 profile;
- iPhone 13 Pro profile;
- iPad Air 4 profile;
- Reduce Motion;
- Low Power Mode or an injected equivalent policy test.

No workflow_dispatch is authorized for this Inbox proposal.

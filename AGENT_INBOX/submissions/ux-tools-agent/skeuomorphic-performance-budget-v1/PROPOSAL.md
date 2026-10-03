# Proposal

## Goal

Introduce one deterministic policy that turns the existing device/runtime performance signals into concrete skeuomorphic rendering budgets.

The proposal is designed for the current Tool Center, arcade consoles and Tactical V2 direction without modifying those UI files directly.

## Current problem

VeilLink already has several good performance gates:

- DevicePerformanceProfile classifies SE1, iPhone 7, SE2, iPhone 13 Pro and iPad Air 4.
- VeilRenderProfile identifies the iPhone 7/iOS 15 legacy compositor path.
- PerformanceOverridePolicy handles Reduce Motion, God-mode full visuals and persistent-motion permission.
- VeilMotionPolicy exposes coarse booleans such as full spatial effects and continuous decorative motion.

The missing layer is a shared quantitative budget for modern skeuomorphism.

Without it, each new physical component decides independently how many shadows, overlay layers, animated glows, 3D tilt degrees, gauge segments or decorative animations it may use. That makes it easy for a visually rich Tool Center or Tactical surface to exceed the safe complexity envelope on iPhone 7 even when every individual component is technically following a boolean gate.

## Proposed behavior

Add four surface roles:

- denseScroll
- toolPanel
- arcadeConsole
- tacticalMap

Add three visual tiers:

- essential
- efficient
- full

The pure policy resolves a VeilSkeuomorphicRenderBudget from:

- device visual complexity;
- legacy compositor status;
- runtime low-power / thermal constraint;
- Reduce Motion;
- explicit full-visual override;
- persistent-motion permission;
- surface role.

The resulting budget contains:

- outer shadow layer count;
- maximum shadow radius;
- maximum decorative overlay layers;
- inner highlight permission;
- specular gradient permission;
- backdrop-material permission;
- animated-glow permission;
- 3D-tilt permission and maximum degrees;
- maximum simultaneous continuous decorative animations;
- gauge segment limit;
- speaker-grille/detail density scale.

## Tier rules

Automatic mode:

- minimal visual complexity -> essential;
- runtime constrained -> essential;
- balanced or legacy compositor -> efficient;
- modern full complexity -> full.

Explicit full-visual override may force the full tier, matching existing God-mode semantics.

Reduce Motion does not flatten all static depth. It removes 3D tilt and continuous decorative animation while leaving static material hierarchy available.

Persistent decorative animation remains independently gated.

## Surface caps

Even a full-tier device gets role-specific caps.

### denseScroll

Limit off-screen composition pressure in long scroll surfaces:

- at most one shadow layer;
- shadow radius <= 4;
- no backdrop material;
- no animated glow;
- no continuous decorative animation;
- tilt <= 2.2 degrees.

### toolPanel

Uses the tier budget unchanged because a focused instrument panel has bounded visible complexity.

### arcadeConsole

Allows high detail but caps:

- shadow radius <= 8;
- tilt <= 4 degrees;
- at most one continuous decorative animation.

### tacticalMap

The map renderer already carries significant draw cost, so decorative chrome is capped:

- at most one shadow layer;
- no backdrop material;
- no animated glow;
- no 3D tilt;
- zero continuous decorative animations;
- gauge segmentation capped at 8.

## Architecture / implementation

The proposal adds one new Core file and one new XCTest file.

VeilSkeuomorphicPerformancePolicy is pure and directly testable.

VeilSkeuomorphicPerformance is a thin runtime adapter that maps current VeilLink state into the pure policy using:

- VeilDevicePerformance.current.transferVisualComplexity;
- VeilRenderProfile legacy and animation gates;
- PerformanceOverrideStore snapshot;
- low-power mode;
- serious/critical thermal state.

The patch intentionally does not modify VeilMotionKit, SkeuomorphicComponents, ToolCenterView, ArcadeGameViews or Tactical V2 files. The Integration Governor can bind accepted UI components to the budget during a controlled integration batch.

## User-visible impact

After UI adoption:

- iPhone 13-class devices retain rich physical depth and interaction.
- iPhone 7/iOS 15 keeps the same design language but automatically uses cheaper shadows, fewer overlays and no continuous decorative effects.
- low-power or thermally constrained devices degrade immediately to an essential static physical hierarchy.
- Reduce Motion users keep readable physical structure without spatial movement.
- Tactical V2 cannot accidentally stack expensive cosmetic effects on top of its large map renderer.

## Compatibility

- iOS 15+ compatible.
- No transport/storage/protocol/schema/identity changes.
- No A9/A10 governance changes.
- No network or persistence.
- No version/build/release changes.
- No external dependencies.
- Existing performance policy behavior remains unchanged until a UI opts into the new budget.

## Alternatives considered

### Keep using only boolean gates

Rejected because independent components can all pass the same boolean gate and collectively exceed the safe visual budget.

### Hard-code iPhone 7 checks in every view

Rejected because it duplicates machine logic and makes future hardware policy changes error-prone.

### Modify PR #10 UI files directly

Rejected under Inbox overlap discipline. The new budget is proposed independently and PR #10 consumption is left to the Integration Governor.

### Disable all skeuomorphism on old devices

Rejected. The goal is graceful reduction, not visual identity loss.

## Acceptance criteria

1. Pure policy returns essential for minimal complexity or constrained runtime in automatic mode.
2. Legacy balanced devices resolve to efficient rather than full.
3. Modern full devices retain the full tool-panel budget.
4. Reduce Motion removes tilt and continuous animation without erasing static depth.
5. Explicit full-visual override can force full transient visuals.
6. Continuous decoration remains separately permission-gated.
7. Dense scroll, arcade and Tactical surfaces enforce their role caps.
8. No existing VeilLink source file needs modification to compile the policy proposal.

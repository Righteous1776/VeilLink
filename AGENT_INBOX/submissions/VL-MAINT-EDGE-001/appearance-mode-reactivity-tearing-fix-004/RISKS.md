# Risks

## Protected surfaces

None.

This proposal is restricted to visual rendering and appearance tests. It does not change:
- transport;
- storage or database schema;
- identity/key management;
- wire protocol;
- A9/A10 governance;
- workflows;
- signing;
- release/version values.

The Lane Agent does not modify the product tree directly; `PATCH.diff` is advisory.

## Cross-agent overlap

A changed-file audit was performed against all currently open PRs visible at preparation time, including:
- legacy #9 and #10;
- Inbox #18-#21;
- game/render proposals #25-#35;
- current Codex Inbox #49-#54.

No direct overlap was found with:
- `VeilLink/Core/AppTheme.swift`
- `VeilLink/Core/SkeuomorphicComponents.swift`
- `VeilLink/Core/VeilMotionKit.swift`
- `VeilLinkTests/GlobalAppearanceModeTests.swift`

The Governor must re-check later submissions before batching.

## Behavioral risks

### Extra SwiftUI invalidations

Adding `@ObservedObject` means the affected material surfaces explicitly repaint when `selection`, `colorMode` or automatic-system darkness changes.

This is intended. The controller has a very small publication surface and these changes are user/system appearance events, not high-frequency telemetry.

### Dynamic glow state

`VeilDynamicGlowBorder` owns `@State rotates`. Re-rendering because appearance changed must preserve the existing state identity; the proposal does not add `.id` or reconstruct the root.

Integration testing must confirm the glow does not restart continuously or leak animation work after mode switching.

### Existing UIAppearance behavior

`VeilChrome.configure()` uses UIKit appearance proxies. This proposal does not redesign that path.

The supplied defect is reproducible in SwiftUI material layers, and this patch addresses their missing dependency. If an existing UIKit bar still fails to refresh independently after this patch, that should be filed as a separate chrome-specific task rather than reintroducing a root reset.

## Migration / compatibility risks

No migration.

`ObservedObject` is supported by the deployment target and is already used in VeilLink's Settings and root views.

The source-level regression test uses `#filePath` to locate repository source during XCTest. Xcode/GitHub Actions checkouts provide these paths. If a future test packaging environment strips source files, the architecture test may need to move to static preflight instead of weakening the product fix.

## Performance / battery risks

Low.

There is no timer, polling loop, display link, network work or background task.

Cost is bounded to repainting five central visual renderers when appearance state actually changes.

Rapid-toggle testing is required to confirm no update loop.

## Security / privacy risks

None expected.

No user data, messages, identifiers, credentials, permissions or telemetry payloads are added.

The supplied screen recording is used only as local debugging evidence and is not committed to the Inbox.

## Why a broader rewrite is not proposed

The current palette/controller architecture can support correct day/night rendering. Replacing it with a new Environment theme engine would touch a large fraction of the UI and create avoidable regression risk.

This task fixes the concrete missing dependency at the central material boundary.

## Rollback strategy

Revert the four-file patch.

No data migration, cache purge or settings reset is required. Existing persisted appearance selection and color-mode values remain valid.

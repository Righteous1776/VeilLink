# Proposal — Inbox feature convergence foundation

## Outcome

Add a small common registry and one Feature Library screen so accepted Inbox packs stop competing for `ToolCenterView`, can be searched without repeatedly scanning/rendering every feature, and fail closed when their required verification is missing.

This is an integration foundation, not blanket acceptance of every Inbox claim. Catalog-only, external-ZIP-only, duplicated and superseded proposals must not become runnable entries merely because they exist in the Inbox.

## Behavior

- Reject empty or case-insensitively duplicated feature IDs.
- Precompute ID, domain and normalized-search indexes.
- Cap a query page at 100 items; the proposed UI renders 30 lazy rows at once.
- Record pack-level conflict groups so incompatible implementations are visible.
- Gate launch on P0 touch, data continuity, Apple build, physical-device proof and requested permissions.
- Select static/reduced/standard/high rendering from accessibility, legacy-device, low-power and thermal state.
- Preserve Owner God Mode high-quality rendering except at critical thermal pressure.
- Instantiate destinations only through an integration-owned resolver after a launchable row is tapped.

## Deliberately excluded

- No Tool Center mutation. The Governor should add exactly one Feature Library entry after accepted packs and routing are assembled.
- No automatic import of another lane's patch.
- No version/build bump, workflow dispatch, IPA, tag, release, protocol, schema, Keychain or A9/A10 mutation.
- No claim that design rows are implemented product features.

## V27.0 relationship

Use this proposal before integrating the large V27.0 Inbox batch. Select one canonical source generation per feature/game, register only sources that pass the Apple/iPhone gates, then expose the resulting set through one navigation surface.

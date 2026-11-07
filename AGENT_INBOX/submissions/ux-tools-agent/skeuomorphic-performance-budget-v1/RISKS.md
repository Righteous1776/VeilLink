# Risks

## Protected surfaces

None are directly touched.

The proposal does not modify workflows, project files, versions/builds, release/signing, protocol, schema, identity, transport, storage or A9/A10 governance.

## Cross-agent overlap

Direct file overlap at preparation time:

- PR #10: none.
- PR #4: none.
- VL-MAINT-EDGE-001 DeepTelemetry drop: none.
- ux-tools-agent local-tool-complexity-engine-v1: none.

Behavioral adjacency exists with PR #10 because that proposal owns the skeuomorphic Tool Center / arcade / Tactical UI. This submission deliberately does not edit those files or decide integration order. VEILLINK-IG-001 must arbitrate when and where the budget is consumed.

## Behavioral risks

### Over-conservative caps

Dense-scroll and Tactical caps may visually reduce effects on high-end devices. The policy preserves physical hierarchy but prioritizes bounded composition cost.

### Budget fields are policy, not measured GPU cost

Values such as shadow layers and overlay limits are deterministic engineering limits, not direct millisecond/GPU counters. They should be validated against real iPhone 7 and iPhone 13-class hardware during integration.

### Role misclassification

A caller choosing toolPanel for an unbounded scrolling surface could receive a richer budget than intended. UI integration should use denseScroll for long lists/grids and tacticalMap for map-heavy surfaces.

### God-mode override

Explicit full-visual override can intentionally exceed automatic safety tiers. This matches existing repository semantics. Persistent decorative animation still remains independently controlled.

## Migration / compatibility risks

The patch is additive and not consumed by existing code automatically. Therefore it cannot change current rendering until an integration batch wires views to it.

If PR #10 evolves its own competing budget model before integration, the Governor should select one design or rewrite both rather than merging duplicate policies.

## Performance / battery risks

The policy itself is constant-time and allocates only a small value struct.

Runtime adapter reads existing device/profile flags and ProcessInfo state. It introduces no timer, observer, polling loop, background task or persistent cache.

The actual performance benefit depends on UI adoption.

## Security / privacy risks

No data, message content, identity, telemetry, network or storage information is processed.

## Rollback strategy

Because both proposed files are additive:

1. omit or remove them from an integration batch;
2. remove any later UI call sites if already wired;
3. no schema/data migration or cleanup is required.

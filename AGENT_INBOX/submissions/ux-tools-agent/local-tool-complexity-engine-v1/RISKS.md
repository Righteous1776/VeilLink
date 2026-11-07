# Risks

## Protected surfaces

None intentionally touched. No workflows, project config, version/build, release/signing, transport, storage/schema, identity, protocol or A9/A10 changes.

## Cross-agent overlap

Direct changed-file audit:
- PR #10: no overlap with VeilLocalToolEngine.swift or VeilLocalToolEngineTests.swift.
- PR #4: no overlap with either proposed file.

Behavioral adjacency exists with PR #10 because its Tool Center UI could later consume these metrics. This submission intentionally does not modify ToolCenterView.swift. Integration order is left to VEILLINK-IG-001.

## Behavioral risks

- Character counts are grapheme-based while ASCII ratios are Unicode-scalar based; names document this distinction.
- JSON root depth is defined as 1.
- Encoding expansion percentage is rounded to the nearest whole percent.
- AA booleans refer only to the preferred black/white foreground, not arbitrary colors.

## Migration / compatibility risks

The API is additive and stateless. Existing transformation APIs are unchanged.

## Performance / battery risks

- Text metrics are O(n).
- JSON structure analysis is O(nodes) with an explicit heap-backed stack.
- Encoding metrics reuse existing transformations.
- Color analysis is constant time.
- No background work, polling, network or persistence is introduced.

## Security / privacy risks

All computation remains local. No new logging, telemetry, persistence, clipboard behavior or network path is introduced.
JSON analysis returns only counts/depth and does not persist contents.

## Rollback strategy

If integration fails, omit/revert the two-file patch. No data migration or cleanup is required.
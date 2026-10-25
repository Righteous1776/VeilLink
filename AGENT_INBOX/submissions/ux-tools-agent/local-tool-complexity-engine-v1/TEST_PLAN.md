# Test Plan

## Static checks

- Patch applies cleanly to base main c81f266e0032a1d0868cb25ddc26b690ddea4e43.
- Proposed product changes are limited to VeilLocalToolEngine.swift and VeilLocalToolEngineTests.swift.
- No workflow/project/version/protocol/schema/identity/A9/A10/release changes.
- New value types are Sendable.

## Unit tests

Add four focused XCTest cases:

1. testDetailedTextMetricsExposeWordsAndASCIIRatio
   - mixed ASCII/CJK/newline text;
   - verify characters, UTF-8 bytes, lines, words, scalar counts and 867 permille ASCII ratio.

2. testJSONStructureMetricsCountNestedContainersAndDepth
   - verify 2 objects, 1 array, 3 scalars, 3 keys, depth 4 and 6 total nodes;
   - malformed JSON must throw invalidJSON.

3. testEncodingMetricsReportDeterministicExpansion
   - abc -> Base64: 3 to 4 bytes, +33%;
   - a b -> URL percent: 3 to 5 bytes, +67%;
   - empty Base64 input returns zeros.

4. testColorContrastChoosesReadableForeground
   - black luminance 0, white contrast 21:1, preferred white;
   - white luminance 1, black contrast 21:1, preferred black;
   - invalid RGB throws rgbOutOfRange.

## Integration tests

If later wired into PR #10 Tool Center UI:
- JSON gauges update only for valid parse results.
- Encoding gauges use UTF-8 byte counts.
- Color Lab consumes the engine's preferred foreground instead of duplicating luminance math.
- all behavior remains offline.

## Negative / failure cases

- empty text;
- Unicode/CJK/emoji text;
- invalid JSON;
- top-level JSON fragments;
- empty encoding input;
- invalid RGB;
- deeply nested JSON must use iterative traversal.

## Regression invariants

Password generation, SHA-256, current textMetrics, JSON formatting, Base64/URL codecs, ISO8601 conversion, cleaning, HEX/RGB conversion, random/dice and Morse behavior must remain unchanged.

## Device / OS coverage

During Governor integration run normal static preflight, iOS Simulator build and full XCTest inventory, retaining iOS 15 compatibility.
No workflow_dispatch is authorized for this Inbox proposal.
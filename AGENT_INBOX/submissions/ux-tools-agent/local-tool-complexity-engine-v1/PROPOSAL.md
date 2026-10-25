# Proposal

## Goal

Increase the functional depth of VeilLink's existing local utilities without touching their current UI integration lane.

The proposal gives Tool Center richer deterministic facts that can be surfaced by the skeuomorphic instrument UI later:
- detailed text composition metrics;
- JSON structure metrics;
- Base64 / URL encoding expansion metrics;
- color luminance and contrast/readability analysis.

## Current problem

The current VeilLocalToolEngine implements useful primitives, but most tools expose only the direct transformation result. This makes the new instrument-style Tool Center visually richer than the underlying data model.

Examples:
- Text Fingerprint has character/UTF-8/line counts but no word, Unicode or ASCII composition data.
- JSON can validate/pretty-print/minify but cannot report structural complexity.
- Base64 and URL codecs transform text but cannot report size expansion.
- Color Lab converts HEX/RGB but cannot report luminance, contrast, or a readable foreground recommendation.

These are good engine-level additions because they are deterministic, offline, small, testable and dependency-free.

## Proposed behavior

### Detailed text metrics
Add VeilDetailedTextMetrics and VeilLocalToolEngine.detailedTextMetrics(_:).
Report grapheme characters, UTF-8 bytes, lines, words, non-whitespace scalars, Unicode scalars, ASCII scalars and ASCII ratio permille.
Existing textMetrics(_:) stays unchanged.

### JSON structure metrics
Add VeilJSONStructureMetrics and jsonStructureMetrics(_:) throws.
Report object count, array count, scalar count, key count, maximum depth and total node count.
Traversal uses an explicit stack rather than recursive calls.

### Encoding expansion metrics
Add VeilEncodingMetrics plus base64EncodingMetrics(_:) and urlPercentEncodingMetrics(_:).
Report input bytes, output bytes, delta bytes and rounded expansion percent.

### Color contrast analysis
Add VeilPreferredForeground, VeilColorContrastAnalysis and colorContrast(rgb:) throws.
Use standard sRGB relative luminance math to report contrast against black/white, preferred foreground, preferred contrast and AA normal/large text booleans.

## Architecture / implementation

The proposal is additive. No existing method signature changes and no current transformation output changes.
Implementation remains inside VeilLocalToolEngine.swift and uses only Foundation/CryptoKit already present.
JSON analysis reuses the current parser. Text analysis reuses the existing basic metrics. Color analysis stays UI-framework independent.

## User-visible impact

No UI file changes are proposed.
If selected by the Integration Governor, PR #10 Tool Center can later display these values as LCD/gauge telemetry without moving analysis logic into SwiftUI.

Likely UI opportunities:
- JSON: OBJECTS / ARRAYS / DEPTH / NODES gauges.
- Text: WORDS / UTF-8 / ASCII ratio.
- Base64 and URL: PAYLOAD EXPANSION.
- Color Lab: LUMINANCE / CONTRAST / FOREGROUND.

## Compatibility

- iOS 15+ compatible.
- No networking or persistence.
- No protocol/schema/A9/A10/version/build/release change.
- No new dependency.
- Existing API behavior preserved.

## Alternatives considered

- Compute metrics directly in ToolCenterView: rejected because PR #10 owns that UI and analysis should stay out of SwiftUI.
- Add a third-party utility library: rejected as unnecessary.
- Add many new tools: deferred in favor of deepening existing tools first.
- Recursive JSON traversal: rejected in favor of explicit-stack traversal.

## Acceptance criteria

1. Existing VeilLocalToolEngineTests continue to pass.
2. Mixed ASCII/Unicode text metrics are deterministic.
3. JSON structure metrics count nested containers correctly and reject invalid JSON.
4. Encoding metrics define deterministic and empty-input behavior.
5. Black/white contrast endpoints produce the expected 21:1 ratio.
6. Invalid RGB still throws rgbOutOfRange.
7. Only the two proposed product/test files are required.
# Signal Dive / 深潜信号 V2

## Content expansion
- Adds deterministic biological sonar contacts as a fourth contact class beside terrain, beacons and massive unknowns.
- Fish schools are positioned from the same sonar contact data used by gameplay, eliminating visual/sonar disagreement.
- Biological contacts remain seed-stable and distinct from massive-unknown contacts.

## Direct third-party art
SignalDiveKenneyVectorArt.swift contains two fish variants copied from Kenney Fish Pack 2.0's original vector SVG under CC0-1.0.

Rendering order:
1. optional future PNG alias;
2. direct Kenney vector fish;
3. procedural geometry fallback.

This makes the open-source art active in the renderer today without introducing a network dependency or binary bundle requirement.

## Compatibility
- Reduce Motion suppresses camera shake and lowers particulate density.
- Existing Core Image Bloom remains optional.
- Vector source needs no external parser/library at runtime; the submission includes a bounded M/L/Q/Z path parser.
- Procedural fallback remains available if vector parsing ever fails.

# Open Source / Public Domain Intake — Signal Dive

No third-party code or binary asset is vendored by this submission.

## 1. ShaderKit — MIT — REFERENCE / FUTURE AUDITED VENDOR CANDIDATE

Source:
https://github.com/twostraws/ShaderKit

Use:
- SpriteKit shader architecture;
- GPU noise/ripple/gradient effect reference.

Current action:
- no ShaderKit source copied;
- Signal Dive fog shader is original proposal code.

Future direct-use rule:
- pin exact source/commit;
- include MIT notice;
- vendor only selected shaders rather than the whole demo project.

## 2. Kenney Fish Pack — CC0 — SELECTED ART CANDIDATE

Official source:
https://kenney.nl/assets/fish-pack

Research snapshot:
- 2D underwater/fish pack;
- 120 files;
- CC0.

Recommended workflow:
- select only a small number of silhouettes/ambient fish;
- recolor or render them into the Signal Dive palette;
- do not ship the entire pack if only a few sprites are required.

## 3. Aqualand — CC0 — OPTIONAL UNDERWATER SPRITE REFERENCE

Source:
https://sightseergames.itch.io/aqualand

Research snapshot:
- underwater pixel-art assets;
- includes fish/coral/submarine material;
- page declares Creative Commons Zero v1.0 Universal;
- small download footprint.

Recommended use:
- art/reference or isolated ambience sprites only;
- do not mix pixel-art visual language into the final scene unless art direction is intentionally changed.

## 4. Full engines — NOT SELECTED

Do not embed another engine solely for underwater rendering.

Signal Dive continues the Apple-native SpriteKit/CoreImage stack established by the current Game Agent line.

## Intake principle

1. Prefer CC0 for direct art reuse.
2. Prefer MIT source only when a narrow capability is worth vendoring.
3. Keep gameplay/core/render glue original and auditable.
4. Record provenance before any external asset enters product history.
5. Avoid whole-pack imports when only a handful of assets are needed.

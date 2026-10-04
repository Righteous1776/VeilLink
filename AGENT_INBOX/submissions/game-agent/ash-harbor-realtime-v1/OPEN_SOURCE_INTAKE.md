# Open Source / Public Domain Intake

This file records candidates researched for the Ash Harbor / broader real-time 2D game line.

No third-party source or binary asset is vendored by this submission.

## 1. ShaderKit — SELECTED AS OPTIONAL TECHNICAL REFERENCE / FUTURE VENDOR CANDIDATE

- Source: https://github.com/twostraws/ShaderKit
- License: MIT
- Purpose: SpriteKit fragment-shader patterns such as water ripple, noise, lighting and gradients.
- Compatibility signal: project documentation says shader effects themselves work back to iOS 10; sample app has a newer deployment target.
- V1 action: do not copy code. Use the repository to benchmark effect categories and architecture; V1 water shader is original.
- Future direct-use option: vendor only specific shader files after Governor review and include the MIT notice.
- Package-size impact: tiny source-only shaders.

## 2. LDtk — SELECTED FOR OFFLINE LEVEL AUTHORING

- Source: https://github.com/deepnight/ldtk
- License: MIT
- Current researched release: 1.5.3
- Purpose: author harbor lanes, rescue points, debris, trigger zones and background landmarks visually.
- Runtime strategy: do not embed LDtk. Export simplified JSON and convert to a narrow AshHarbor level format.
- Package-size impact: only the final compact level JSON.
- Benefit: game designers can iterate spatial layouts without editing Swift coordinates.

## 3. Ink / Inky / ink-library — SELECTED FOR NARRATIVE AUTHORING REFERENCE

- Sources:
  - https://github.com/inkle/ink
  - https://github.com/inkle/inky
  - https://github.com/inkle/ink-library
- License: MIT
- Purpose: structure conditional dialogue and state-driven story beats.
- V1 action: no runtime dependency and no copying of sample story text.
- Recommended workflow: author branching beat logic externally, then export/translate only original Ash Harbor lines into a compact runtime table.
- Package-size impact: effectively zero if used as an authoring tool only.

## 4. Kenney Watercraft Kit — SELECTED CC0 ART SOURCE

- Official source: https://kenney.nl/assets/watercraft-kit
- License: CC0
- Researched pack size: 45 watercraft files.
- Purpose: use one or two boat models as an offline base for 2D side-view sprite rendering.
- Recommended workflow:
  1. choose a model;
  2. render only the required side/profile frames in Blender;
  3. recolor/weather to Ash Harbor art direction;
  4. ship the resulting small sprite(s), not the entire 3D kit.
- Attribution: not required by CC0, but optional credit is recommended for provenance.
- Package-size impact: low if pre-rendered and aggressively selected.

## 5. Poly Haven — SELECTED CC0 MATERIAL / LIGHTING SOURCE

- Official source: https://polyhaven.com/
- License: CC0
- Purpose: rusted metal, wet concrete, corrugated iron, harbor-surface reference/material baking and optional HDRI lighting for offline sprite renders.
- Runtime strategy: do not ship 8K source textures or HDRIs. Bake selected material appearance into small 2D atlases/sprites offline.
- Package-size impact: controlled by final bake resolution.

## 6. SKTiled — DEFER

- Source: https://github.com/mfessenden/SKTiled
- License: permissive/MIT-style source headers; verify repository LICENSE before any direct intake.
- Purpose: Tiled map rendering in SpriteKit.
- Reason to defer: capable, but Ash Harbor does not need a runtime tiled renderer yet. LDtk-as-authoring-tool + narrow runtime level data is simpler and lighter.

## 7. TiledKit — DEFER

- Source: https://github.com/SwiftStudies/TiledKit
- Purpose: Swift package for reading Tiled levels and SpriteKit specialization.
- Reason to defer: runtime compression support includes zstd setup and adds dependency surface that the current game does not need.

## 8. OctopusKit — ARCHITECTURE REFERENCE ONLY

- Source: https://github.com/InvadingOctopus/octopuskit
- License: Apache 2.0; includes some MIT shader material.
- Purpose: study SwiftUI + SpriteKit + component architecture.
- Reason not to depend on it: repository explicitly states the sole maintainer no longer updates it.
- Useful idea: keep scene state, gameplay state and SwiftUI HUD separated.

## 9. Godot / AdaEngine — DO NOT EMBED IN VEILLINK FOR THIS LINE

- Godot: excellent MIT full engine, but embedding or migrating would create a second engine/toolchain and large integration surface.
- AdaEngine: interesting Swift-native engine, but VeilLink already has Apple-native SpriteKit/SwiftUI infrastructure.
- Use: reference designs/demos only, not runtime dependencies.

## Intake principle

Prefer:
1. CC0 assets for direct art reuse;
2. MIT/Apache tools as offline authoring or small audited dependencies;
3. original VeilLink glue/gameplay code;
4. narrow final assets rather than whole asset packs;
5. explicit third-party notices whenever license requires them.

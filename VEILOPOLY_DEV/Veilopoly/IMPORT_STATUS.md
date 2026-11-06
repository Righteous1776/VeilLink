# Source import status · 2026-11-06

**Source ZIP:** `Veilopoly_P1-P4_checkpoint_20261106.zip`, SHA-256 `d999d29f9e369899cbd666e1cfcb0744a2e17d3d976deb4e2e6a591a5e1923c1`.

**Archive inspected locally:** 64 files (33 Swift source/test files, 5 specification/license Markdown documents, 26 PNG/WAV resources); 38 non-binary entries and 26 binary entries. The ZIP did not include a standalone root README. Local workspace contains later experimental edits not present in the checkpoint ZIP. Do not silently mix the two.

**GitHub import stage:** package manifest and coordination documents committed. The bulk source tree, XCTest files, and binary resources are **NOT yet committed** into this branch. Do not mistake the ZIP previously issued in ChatGPT for an automatically synchronized GitHub folder.

The `Package.swift` targets will compile only after their matching Sources/Tests/Resources directories are imported. The current branch is NOT a complete Swift package and has not passed its own CI.

## Expected incoming folders

```text
Veilopoly/
├── Package.swift                     # committed
├── Sources/
│   ├── VeilopolyEngine/             # pending: Models, Board, Rules, SampleCards
│   ├── VeilopolyAI/                 # pending: AI.swift
│   ├── VeilopolyNet/                # pending: Net.swift
│   └── VeilopolyUI/                 # pending: UI, BoardScene, RenderCommands, Resources
├── Tests/
│   ├── VeilopolyEngineTests/        # pending: 20 move/determinism/support test files
│   ├── VeilopolyAITests/            # pending: 2 test files
│   └── VeilopolyNetTests/           # pending: 1 test file
└── docs/                            # pending: game/modeling/rendering specs & licenses
```

## Native test claims

The checkpoint package was previously tested with the Linux Swift toolchain, and earlier results reported 24 passing XCTest checks. This status report has NOT rerun iOS SDK tests for this GitHub branch. Never relabel ZIP-local tests as CI results from this branch.

## Mandatory next work

Complete exact file-by-file import of the ZIP into `dev/veilopoly:VEILOPOLY_DEV/Veilopoly/`, verifying hashes and source license. Then run Swift package build and tests; separately validate SwiftUI/SpriteKit on iOS via Xcode. Only after all exact resources are committed may the directory be marked `SOURCE_IMPORTED`.

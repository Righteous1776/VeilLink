# Test plan — board side selection R1

## Executed here

- Candidate diff whitespace validation: PASS.
- Static inspection confirms changing to second colour resets the board then schedules the first computer move.
- Static inspection confirms native and external Gomoku engines and XiangqiBot receive the selected computer side.
- Static inspection confirms learning plies retain local-player/computer semantic roles irrespective of physical colour.
- Authored XCTest checks second-colour Gomoku begins with exactly one computer black stone and returns control to the player.

No Xcode/iOS SDK exists in this Linux runner; no XCTest result is claimed.

## Governor/device gates

1. Apply after resolving the #112→#114 stack and run XcodeGen plus full XCTest.
2. Gomoku: choose black then white; verify black begins every time, white selection gets exactly one AI opening, and switching mid-game restarts without clearing archives.
3. Xiangqi: choose red then black; verify red opens and black selection receives exactly one legal AI red move.
4. Enable/disable PVS/VCF, formation preference and native training evidence under both colours; confirm actor/legal-move checks and forced tactics remain correct.
5. Play complete games as both colours, restart and export/import training; verify no role reversal, double count or archive overwrite.

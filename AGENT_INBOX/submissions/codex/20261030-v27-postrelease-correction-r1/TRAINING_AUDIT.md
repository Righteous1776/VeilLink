# Attached board-learning package audit

File: `VeilLink-BoardLearning-20261030-183350.vltrain.json`

- bytes: 55,049
- SHA-256: `4c7332610283edc69c2e02f985c64851a4b1b4d671e20101b9e216c43002af43`
- format: `veillink.board-learning.export.v1`
- app version: 27.0
- payload checksum algorithm: `fnv1a64-canonical-json`
- payload checksum: `58fa6c39066f6f0c`
- completed games: 2
- positions: 222
- recorded games: 13
- position prefixes: 222 × `g:`, 0 × `x:`
- game kinds: 13 × Gomoku, 0 × Xiangqi
- results: 2 human wins, 11 unfinished

Conclusion: the screenshot showing “2 局 / 222 局面” on both Gomoku and Xiangqi is a product bug. The package contains no Xiangqi evidence; V27 displayed one aggregate shared store in both screens.

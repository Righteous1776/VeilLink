# VeilLink Gomoku native self-play R3 (2026-10-31)

## What was actually trained

The same Swift native chess logic as the product's \`GomokuState\`, \`GomokuBot.chooseMove\`, \`GomokuFormationPreference\` and \`AdaptiveBoardPosition.gomoku\` was extracted at GitHub commit \`bc919b454379841180fb8698a9e0addec87e7af0\` and compiled on Linux (Swift 6.2.1, optimized). This is genuine **native Bot-vs-Bot game search**, not an image classifier and not a Python move generator. The opening **first black move is explicitly seeded** from 81 center-area start squares; all subsequent 91,530 moves are chosen by the native Swift Bot. Both sides vary among six formation preferences and three bounded native search budgets.

The generated record package is bundled in the app at \`VeilLink/Resources/GomokuNativeTrainingSeed.json\`. The app must independently replay **every move** through \`GomokuState.apply\`, check a real terminal winner/draw and validate the complete-archive FNV1a64 before importing any results. No synthetic image diagram, incomplete game, random fake game, or arbitrary terminal label counts.

| Measurement | Verified result |
|---|---:|
| Native completed matches | 2,000 |
| Native Bot decisions made | 91,530 |
| Total stones placed (including 2,000 preset black openers) | 93,530 |
| Unique full move sequences | **236** |
| Unique before-move position hashes | 10,710 |
| Black/host wins | 1,102 |
| White/guest wins | 860 |
| Draws | 38 |
| Opening index choices | 81 |
| Black-vs-white formation mode combinations | 36 |
| Invalid or unfinished matches after independent replay | 0 |
| Bundled JSON byte count | 178,125 |
| Bundled SHA-256 | \`9f7ddf5c847d6beb972c5a98ad83daa66df189f82171988ac1da68d6142188e0\` |
| Bundled FNV1a64 | \`29e9808a4a69618b\` |

Training is **evidence collection**, not proven Elo improvement. Most games repeated earlier complete move sequences. The exact-position memory does not automatically generalize to new board shapes. This set must NOT be promoted as a 2,000-unique-game strong policy or as actual device validation.

## Product integration

- First install only: load bundle, validate checksum and legality on a detached worker, then durably append to isolated \`gomoku-native-selfplay-v1.json\` in a **single atomic batch**. Already nonempty archives are never overwritten or double counted.
- \`trainedNativeGames\` displays **persisted** completed match count, not the source ZIP's length or pending jobs.
- Selected native training is a separate evidence layer, bounded to small positional score adjustments. The native Bot's immediate win/forced-defense guards still execute before learning scores.
- Human training history and Xiangqi remain separate. Turning off the native-learning switch retains the existing external PVS/VCF engine selection.
- Player can run extra 10/100/1,000 native games using the same engine on device. Only fully terminal, saved games count, and user can stop the session.
- Do not claim the bundle is live in production until full CI, resource-in-bundle unit test, physical iPhone performance and release gates pass.

## Provenance and gates

- Training scripts, raw JSONL game traces, independent Python replay audit, checksum manifest and full zip are delivered separately as owner-side verification resources.
- iOS CI requires green: app/simulator builds; actual 2,000 match bundled replay test; corrupted bundle rejection; actual native match legal replay; cold-loaded database counts; standard other game tests; unsigned packaging.
- Before claiming stronger play, run an independent, balanced, **held-out paired tournament** versus untrained baseline and PVS/VCF where available. Include opening diversity, draw rate, duplicate rate, time budget, device thermals, crash and power metrics.
- This PR is stacked \`#114 -> #113 -> #112 -> main\`, remains DRAFT and must not be blindly merged or released.

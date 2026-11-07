# VEILOPOLY-HALL-NEWS-008 — game-hall and live news integration

## Authority and baseline

Owner requested actual hall integration and the previously requested scrolling notifications, then instructed **no new version output yet**. This expands the old development-only scope solely to `VeilLink/UI/GameLobbyView.swift` and `project.yml` for local hosting, not product transport. Work remains on `dev/veilopoly`.

- Starting branch: `ac1805a3f8dcf4c1a657ecfff0f64650f037b736`.
- Main / merge base: `ccafebab147e069fbabfff579dbf323b0d54f191`.
- All existing branch game/finance/AI/art/editorial/persistence work retained.
- Version **27.2 / build 64 unchanged**. No workflow, signing, release, protocol, schema, key, other-game or governance edits.

## Actual wiring

`GameLobbyView` → local-game “大富翁 · Veilopoly” → `veilopolyFullscreen` → actual `VeilopolyGameView`, not a screenshot or web preview. XcodeGen links the local Swift package's `VeilopolyUI` product and its engine/AI/persistence dependencies. Existing save/resume and exit flushing remain active. An omitted seed now allows fresh-game entropy; explicit test seeds and saved seeds still work.

The host already permits both landscape orientations. Existing iOS 15 fallback and iOS 16+ scene geometry request remain; actual hosting-controller rotation/restoration requires Apple SDK acceptance. Local mode only: no real VeilLink multiplayer transport integration is claimed.

## Restrained live ticker

- Single-line ivory/gold/deep-teal pill beside the board, away from More/Exit; no barrage, sound or touch interception.
- **86 offline copy entries:** 36 ambient city lines + 50 event-template variants.
- Successful committed effects supply real income/payment, rent, property purchase, auction, construction, mortgage/redemption, completed trade, stock execution, bank maturity, card, bankruptcy and victory notices. Market news requires a real regime change/new halt.
- No fabricated financial effect or game-rule change; outstanding unpaid rent is not announced as collected. Routine dice, movement, bids and market ticks are filtered.
- Queue cap 6; topic cooldown 60 seconds; priority ordering. Each item displays 14 seconds with an 8-second gap. Ambient news is eligible only when idle, at least 45 seconds after the previous ambient item. Foreground logical time only; no background catch-up flood.
- Overflow waits 2 seconds then scrolls over 10. Short text pauses the animation clock. Background/Reduce Motion pauses scrolling; return to foreground restarts reading. Full sentence is available to VoiceOver without forced live announcements.
- More menu pauses/re-enables news. Match reset clears old messages. Copy selection uses an independent local RNG counter, never gameplay RNG; feed is presentation-only, not saved/broadcast game state.

## Actual offline content contract

Tests resolve aliases through the real `Bundle.module` and check PNG signatures, rather than assuming that an incoming-art folder is shipped:

| Content | Count |
| --- | ---: |
| Runtime PNG | 99 |
| WAV audio | 13 |
| Dice XML | 1 |
| Card editorial | 32 |
| Street pages | 40 |
| Issuer dossiers | 5 |
| Guide topics | 23 |
| News entries | 86 |

SwiftPM `.process("Resources")` carries the runtime payload with the linked module. Editable masters, reference sheets, mockups and unselected dead-control art remain development material rather than being bundled wholesale. No network download is needed. This proves local package-bundle presence, **not installation on Owner's phone**.

## Verification

- Final `swift test --jobs 2` → **237 tests / 0 failures, PASS (Linux)**, including 8 bulletin and 2 offline bundle regressions.
- `swiftc -frontend -parse -target arm64-apple-ios15.0` on hall, UI, ticker and presentation → no syntax errors → **PASS, grammar only**.
- YAML parsing → app links local package, version/build unchanged → **PASS**.
- `git diff --check` → no whitespace errors → **PASS**.
- Full Apple SDK build/link, XcodeGen generation, orientation, SpriteKit drawing, touch, accessibility, audio, GPU timing and installation → no Apple tooling in this environment → **PENDING**. Linux excludes iOS-only UI; it is not Apple build evidence.

## No-version boundary and next task

No IPA, release, workflow dispatch, main merge or PR. Existing `ios-ci.yml` packages a candidate IPA on PRs; merging the modified `project.yml` to main triggers `core-release.yml`. These workflows are unchanged, not bypassed. Source push to the development branch is delivery, not release.

Next: in an authorized Apple environment run XcodeGen and host compile/tests without packaging; validate hall entry, all 40 cells, ticker/capsule separation at 844×390, 852×393 and 1180×820, lifecycle, save/resume and exit orientation. Owner must request version output again before using IPA-producing paths.

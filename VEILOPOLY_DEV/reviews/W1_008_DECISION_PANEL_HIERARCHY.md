# VLP-CODEX-W1-008 — decision panel hierarchy and adaptive actions

Branch `dev/veilopoly`; before `8f4898de38040db8f196d97fc855df16357d3bd0`.
Main verified unchanged `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
Owner asked to continue UI design. W1-007 Apple acceptance is still blocked on
the Linux executor; this is a separate authorized source-only refinement, not
a substitute claim of Apple acceptance. Only `VEILOPOLY_DEV/**` changes.

## Actual implementation

- Preserve the movable/suspendable workspace, viewport clamps, board geometry,
  themes, numeric keypad, real reducer actions and all accepted assets.
- Purchase: native title + current price + cash remaining; do not print a false
  negative available balance. Real reducer preview determines buy availability.
  Gold/teal Astra paper hero and detailed deed remain in an optional disclosure.
  Explicit explanation distinguishes public auction from simply skipping.
- Auction: native live highest price/leader, editable bid, minimum permitted bid
  and a 44pt **fill minimum** action (draft only; never submits). Positive bid
  validation shares the actual reducer. Empty/zero/negative input cannot become
  a fold through the bid button; the separate fold still sends amount0. Retain
  existing interactive artwork and civic notice in a details disclosure.
- Trade: show recipient-relative **you give / you receive**, actual cash, full
  property names and both deck-specific jail-card counts, other party and cash
  after trade. Acceptance is reducer-preview validated. Cash-only counteroffer
  is a labelled disclosure; it still preserves property/card terms and needs
  the other player's acceptance. Full art/contract remain accessible below.
- Buy/auction/trade accept-or-decline actions are now pinned OUTSIDE the scroll
  view, like the existing manage-phase end-turn. Awaiting/animation/offline gates
  hide them rather than allowing repeat submission. Card modal stays above them.
- Shared native headings and metric rows create a consistent instrument-like
  hierarchy. Decisions use at most two action columns (112pt minimum preferred
  width,8pt gap), one for narrower or accessibility text. Metrics switch to
  stacked labels/values at accessibility sizes. No GeometryReader height loop.
- Astra primary metal buttons use dark teal ink instead of pale labels over
  gold. Secondary metal gets a dark scrim. Inspecting actual bundled disabled
  texture revealed its baked lock: do not overlay a second glyph there. Real
  action SF Symbols occupy the reserved leading gutter ONLY when enabled.
  Dynamic subheadline labels wrap, with a >=44pt body rather than tiny scaled
  one-line labels. Existing skin aliases, pixel payloads and licensing untouched.
- Jail action label now reads the existing `VeilopolyCityLongEconomy.bail(game)`
  (classic50 / current city150), not the previous unconditional50. No fee, rule,
  RNG, move encoding, network, persistence or save changes.

## Evidence

Linux Swift6.2.1 only. New `DecisionReviewTests` test current price/cash, exact
purchase and accepted-trade reducer comparison, both trade perspectives,
cash conservation/no state hash mutation, invalid indices and numeric bounds,
zero bid vs fold, authoritative rejection, classic vs city values and action
column/accessibility policy. Rendering, Dynamic Type and tap quality cannot be
certified by these data tests.

- First new selection10/10 PASS; UI selection120/120 PASS before the extra
  city-price/bail case was added. Final results below supersede these counts.
- Final UI selection → **121 cases / 0 failures / 1.068s** → PASS. New
  DecisionReviewTests11/11 PASS, including final city-price/bail coverage.
- Full exact-source package → **340 cases / 1 failure / 68.532s** → FAIL.
  Same `MalformedTurnReferenceTests.testMalformedTradePartiesAndTiles:21`
  as W1-006; that earlier receipt includes a clean fb245c3 archive reproduction.
  Engine and the failing test remain unmodified. No whole-package PASS claim.
- `swiftc -frontend -parse -target arm64-apple-ios15.0` on changed Swift source
  and tests → syntax-only PASS; staged diff/scope/whitespace review → PASS.
- Apple SDK SwiftUI/host typecheck, iOS XCTest, screenshots, real iPhone/iPad
  touch/VoiceOver/focus/layout/contrast/FPS/battery → **NOT_RUN**. No xcodebuild
  in this executor; no PR/workflow/IPA dispatch to claim those gates.
- Strict warnings-as-errors NOT_RUN; known historical Codable warnings remain.

## Review cautions / next one task

`VLP-CODEX-W1-007`: Apple compile + rendered UI acceptance of BOTH W1-006 and
this wave, no IPA. Verify 844×390,852×393,1180×820 and actual safe areas, min44pt
hit tests and accessibility sizes; scroll full deeds/contracts while pinned
decisions remain reachable. Large text may require scrolling within the panel;
do not claim all information is visible simultaneously.

Confirm trade review direction vs actual delivery, min bid only fills, no
accidental fold, zero/over-cash bid disabled, classic/city bail, modal card ACK,
pending host rejection, theme/text contrast (including pressed/disabled), drag
vs scroll/chart/keypad and suspend/resume state. iPad/manual panel placement may
still intentionally overlap board cells; suspension reveals them without zoom.
Pure read-only estimates are not execution guarantees against later host moves.

Keep the separately reproduced baseline trade assertion visible; do not weaken
tests or silently amend engine semantics to make this UI wave look green.
Independent V5/risk/manual lanes left untouched; newest manual lane touches
guide/manual files, none modified here. No cross-agent conflict found on actual
paths. No main/host/protocol/identity/DB/rules/assets/version/workflow edits,
merge, signing, IPA or release.

Governance skill preserved this source/portable/Apple distinction and scoped
continuation. Repository supplemental learning/session/exchange machinery still
absent (see W1-006 receipt); PARTIAL/UNAVAILABLE, not invented gate PASS. Current
Owner + #168 grant is authority; no governance files installed or replaced.

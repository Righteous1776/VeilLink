# Proposal: VeilLink ECLIPSE identity and truthful thinking display

## Source-confirmed facts
Main commit eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0:
- `VeilLink/UI/GameLobbyView.swift`, `LocalAIGameView` currently renders `statusCard`, an optional Grok bot avatar card, `boardQuickControls`, then the board. Grok card around lines 363–379 shows `VeilOpponentAvatarView(mood: grokBotMood, size: 76)` with English `Grok bot`.
- `VeilLink/UI/VeilOpponentAvatarView.swift` loads `GrokBotFull.mp4` or `GrokBotLoop.gif` and has Grok-specific accessibility wording. Merely re-labeling that view would misbrand its media.
- `LocalAIGameController.swift` on main emits `isAIThinking`, `lastDecisionMode`, `lastDecisionMilliseconds`, NOT streaming nodes/depth/PV. Live source exists only as owner-delivered R5 native proposal.

## UX implementation rules
1. `game == .gomoku`: replace existing Grok UI card with `VeilEclipseIdentityCard` (one card, no duplicate), always shown while in Gomoku. All other games retain Grok card and settings.
2. Left: independent 60-64pt original robot glyph (titanium face, slim cyan eyes, broken eclipse ring); right: `ECLIPSE`, `VEILLINK NATIVE INTELLIGENCE`, real stage/status, chevron. Height 76-86pt; maintain board visibility and touch.
3. Tapping opens `ECLIPSE // TRACE`; allow dismissal, state replay, no automatic AI delay or hidden board touch interception. iOS16+ optional detents; iOS15 fallback standard sheet.
4. When real R5 search trace integrated, show `phase`, `completedDepth`, `nodes`, `variation`, `rule` with source/run ID/position hash; ignore late or cancelled events; UI <=8 Hz; no claimed result before engine returns.
5. Not yet available: top-three candidate scores, per-root rejection reasons, complete VCT proofs or calibrated win probability. These must be hidden until a trustworthy backend event exists.
6. Rule-based historical replay is explicitly labeled `历史复盘/非实时搜索`. Example case #72 ply 12: historical actual AI move 83, R4-safe 67/123, 53 empty root candidates.
7. Accessibility: reduced motion, voice over, dynamic type, dark/light. Never change GomokuState during visualization.

## Component and state model
Native UI components: `VeilEclipseIdentityCard`, `VeilEclipseTracePanel`, `VeilEclipseTraceViewModel`, `EclipseBoardAnalysisOverlay`.
States: idle, preparing, validating, forcingSearch, deepening, finalSafety, ready, review, unavailable. Source: live/recorded/historical/unavailable. Search phase must come from a real trace event, not a timer.
Once unified native search is merged, remove obsolete external-toggle wording under separate Governor integration; do not touch old JSCore resource or license in this UI PR.

## Owner design artifact
Separate owner ZIP SHA-256: 6c96ff20646b58b64d894ac1294131172e6b029869f3ef15e872a9fb4b17933e. Contains complete detailed 15KB implementation spec, fully offline 18KB interactive HTML prototype, two mobile browser screenshots, browser validation JSON and acceptance checklist.
**No product UI implementation claimed in this PR.**

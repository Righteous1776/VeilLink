# Risks / overlap

- **R4 experimental search is not production-ready.** It is a 498-line Swift standalone candidate, NOT embedded in product source or trained model weights.
- R2 #186 and R3 #187 both touch protected high-conflict GomokuBot/LocalAIGameController and GameLobbyView UI. Governor must arbitrate integrations; this PR only drops design and cutover gate docs.
- Crucial regression observed: VCF initially overrode defensive root safety in 9/212 realistic fork-danger cases. Corrected in local native source; must preserve both R4 global candidate safety and final postcondition.
- The user dataset does not report which old engine moved; avoid falsely attributing failures to PVS/VCF.
- Native Swift source does not yet port complete VCT or upstream 3^9 pattern table, and does not ingest AdaptiveBoardLearningSnapshot/formation preferences. Do not delete JS until actual parity and learning integration.
- Search scoring heuristic not calibrated to GomokuBot scale; cannot simply add/compare scores from different engines.
- Performance/thermal on iPhone 13/iPad has not been measured; Linux times are not mobile times.
- Retain MIT notice/LICENSE from copyright (c) 2026 workbuddy even if removing vendored JS. The VeilLink root MIT license does not replace upstream attribution.
- Public GitHub Inbox must not contain private 185-game raw user histories, model weights, compiled binaries, ZIP or protected surface edits.

# Product source update in owner patch (actual source is in the owner ZIP)
Current main SHA: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0.

Targets:
1. `VeilLink/UI/VeilEclipseTracePolicy.swift` new, exact standalone Swift code SHA256=39ce72b13233f8c5a85dd8af157c2809ea946a3e8c7826b88d26f429ca26adbf
2. `VeilLink/UI/VeilEclipseIdentityAndTrace.swift` new, exact SwiftUI code SHA256=ba187ced54a8e246eaf4e1a3909f630580477b38bb573a4cce43ce380d0a6d5c
3. `VeilLink/UI/GameLobbyView.swift`: add @State showsEclipseTrace; replace existing optional Grok avatar block with `if game == .gomoku { VeilEclipseIdentityCard(...) } else if oldGrokPolicy { original Grok block }`; add ECLIPSE sheet with `liveMetrics: nil`.
4. `VeilLink/Agent/Games/LocalAIGameController.swift`: computed `eclipseCompletedMoveHistory` returns [] unless outcome is final and journal reconstructs authoritative Gomoku board, contains only committed match moves. No schema mutation.

UI reads only safe `LiveMetrics?` type, with NO coordinate fields. Origin engine trace fields (PV, candidates, threats) must not reach the active SwiftUI widget.

Owner ZIP `VeilLink_ECLIPSE_FairPlay_UI_R7_20261113.zip` SHA256 3cdd877295b8ab3bfdd91506fc35db35b0a79b4acc48f6c03ee708dbc33a4369. Do not edit outside Inbox or merge without Governor review.

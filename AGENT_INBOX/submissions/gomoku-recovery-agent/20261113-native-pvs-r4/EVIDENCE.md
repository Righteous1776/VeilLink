## Source basis
- main eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
- `VeilLink/Resources/GomokuEngineV2/PROVENANCE.md`: upstream `zv38/gomoku-engine` pinned `0d8d6d960ab5d5f89a7219b8b7fe327ebbda4440`
- MIT copyright 2026 workbuddy
- Engine: `VeilLink/Resources/GomokuEngineV2/engine.js`, wrapper `VeilLink/Agent/Games/VeilOfflineGomokuEngine.swift`
- Native prior gate: `VeilLink/Agent/Games/GomokuBot.swift`, `GomokuCounterForkR4.swift`
- UI + controller: `VeilLink/UI/GameLobbyView.swift`, `VeilLink/Agent/Games/LocalAIGameController.swift`
- Prior PRs: #186 R2 safety, #187 R3 thinking UI design
- Local owner source: 498 lines; SHA-256 `5ef02d1128d584046475b014a4f47589377dd19123765d8241b164a19fec1b39`; passed Swift 6.2.1 strict Linux build, 212/212 raw fork-risk and 848/848 four-rotation safety proxy tests
- NO model winrate, iOS code integration, product compile or release yet.

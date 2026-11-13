# [AGENT-DROP] Gomoku Tactical Search V9

- agent_id: gomoku-tactics-agent
- task_id: 20261113-sixfold-search-v9
- base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
- mode: INBOX_ONLY
- status: DROPPED (proposal only; Governor integration pending)
- requested_goal: Strength ambition 6x; three additional difficulty tiers at 2x/4x/6x of Master thinking-time budget
- proposed_files: VeilLink/Agent/Games/LocalAIGameController.swift, VeilLink/Agent/Games/GomokuBot.swift, VeilLink/Agent/Games/XiangqiBot.swift, VeilLink/Agent/Games/VeilOfflineGomokuEngine.swift, VeilLink/UI/GameLobbyView.swift, VeilLinkTests/GomokuBotTests.swift, VeilLink/Agent/Games/GomokuForcingSearchV9.swift
- asset_grant: none; zero binary/model uploads
- excluded: Xiangqi difficulty change, storage/schema, protocol, A9/A10, signing, workflows, main, IPA
- verification: Swift 6.2.1 Linux stand-alone typecheck and three tactical probes PASS; full application build/iOS XCTest/physical devices NOT_RUN
- overlap: existing R4/R6/R8 native Gomoku and 20261031 training Inbox proposals; see RISKS.md

The five required files plus FILES/GomokuForcingSearchV9.swift form one auditable drop.

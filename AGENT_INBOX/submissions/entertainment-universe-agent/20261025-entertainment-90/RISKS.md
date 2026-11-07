# RISKS

- P0 preexisting iPhone7/iOS15 legal-first-sign failure and gesture intercept remain. PR64 root particle, PR65 per-game controls, PR66 UIWindow recorder proposals are currently staged rather than integrated.
- Existing PR67/PR68 20 capability candidates overlap with planned ToolCenter navigation. No edit to GameLobby or ToolCenter in this submission.
- Most catalog entries are DESIGN ONLY and require significant separate engineering. 90 entries must not be construed as 90 working features.
- Standalone SwiftUI candidate not tested on iOS SDK; Linux test validates Foundation only.
- Mixed-device multiplayer and media sync need future consented E2EE compatibility review (freeze Wire v4/SQLite v10 today).
- User-created packs require size limits, license checks and untrusted-content handling. No arbitrary third-party scripts.
- Game engine has 128-turn cap, graph bounds and atomic move checks; native UI still requires device testing.
- No binary assets, old data replacement, database migration, version bump, signed app/IPA, workflow dispatch or release.
- Rollback: do not apply this proposal; existing Build61 main and release remain untouched.

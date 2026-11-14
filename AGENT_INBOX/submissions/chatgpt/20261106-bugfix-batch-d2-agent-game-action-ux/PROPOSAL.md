# D2 — 灵核的“执行建议”按钮不可用

## Evidence
Main `AgentControlCenterSettings` defaults `allowSuggestedGameMoveExecution` to FALSE; `AppModel.executeAgentSuggestedGameMove()` rejects execution while it remains off. But `AgentGameAssistantSheet` currently disables the button only when `intelligence.currentSuggestedAction()` is absent. The permission is configured in a separate control center screen, so the visible button may look executable yet reject the user with a permissions error. Game suggestions can also be absent/stale while a detached rules Bot computes, or while it is not the user's turn.

## Fix
- Expose the existing stored execution opt-in **inside** the game assistant sheet, bound to `model.setAgentSuggestedGameMoveExecutionEnabled`.
- Keep default FALSE (no silent AI action), and explain that only a manual button press can send an E2EE game packet, after AppModel re-reads the current message-derived game session and legally revalidates the candidate.
- Disable execution button if either no current recommended move or permissions disallow.
- Display concise explanatory status for missing permissions vs missing live legal suggestion. Retain the analysis button as read-only.
- Add persistence and safe-reset test; no wire changes or relaxed validation.

This addresses a concrete UX/policy gating defect. It does **not** guarantee suggestions in unsupported games (tactical, artillery, lightTrail, magneticHockey), change bot compute responsiveness, or force invalid/stale moves.

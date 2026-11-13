# Risks, overlap, release hold

- **Strength vs compute**: New 2x/4x/6x are search-time ceilings relative to Master. A 6x increase in chess ability cannot be guaranteed or converted to Elo without a defined test and sufficient paired games.
- **Overlaps**: Existing R4/R6/R8, native self-play, Bagua learning and prior Inbox submissions at AGENT_INBOX/submissions/gomoku-training-agent/20261031-62500-selfplay-tactical-gate-r1 and codex-gomoku-training/native-selfplay-scale-r4-20261031-s1. Governor should confirm those submissions' disposition and choose integration order; do NOT overwrite them.
- **High CPU/battery**: 5.7 seconds per move at 天元 full mode could impact temperature, battery and UX. Limit is user-selectable; no device-forced downgrade; recommend cancellation and foreground-only progressive feedback in a separate UI lane.
- **Proof scope**: V9 proves a restricted forcing-four tree only; it does not exhaust general VCT, Renju forbidden-move rules, or all win/loss positions. It uses current unrestricted five-in-a-row rules.
- **Tactical no-regression**: Forced defense and winning counterattacks must outrank heuristic learned preferences; R4 and R8 test exact indices are frozen.
- **External engine**: JS PVS/VCF is opt-in and does not ingest adaptive training/formation. Increased JS ceiling needs platform deadline test; V9 native forcing proof is not used when external engine succeeds.
- **Compilation**: Swift host compiled with stub; full app requires actual Xcode/simulator CI. project.yml uses source glob? must verify before promotion. No CI green claim here.
- **Scope**: No release, model files, protocol, databases, A9/A10, workflows, or protected surface modified.

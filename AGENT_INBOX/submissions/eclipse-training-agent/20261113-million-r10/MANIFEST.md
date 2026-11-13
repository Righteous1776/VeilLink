# ECLIPSE R10 million-candidate training
agent_id: eclipse-training-agent
task_id: 20261113-million-r10
base_main_sha: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
scope: offline real-board candidate training; proposed ECLIPSE native tree ordering and explicit product bridge
status: DROPPED; locally validated and remote Inbox Gate passed; Governor acceptance/application/release PENDING
asset_grant: NONE

Target source: PR193, 98ac62b1d24fd66bdf242606cc7c666afb1e575b,
AGENT_INBOX/submissions/gomoku-recovery-agent/20261113-native-independent-r5/FILES/.
ECLIPSE identity/fair-play evidence: PR204 at4b73a4f8dc1b7d2bc213574eed985ee3f97546b8.
Latest separate tactical proposals: PR199/V9 and PR206/V10; not applied or overwritten.

Proposed product files: GomokuBot.swift (single bridge hook), new
VeilGomokuUnifiedSearch.swift, VeilGomokuUnifiedBridge.swift,
EclipseTrainedOrdering.swift, EclipseDifficultyPolicy.swift, LocalAIGameController.swift. Six paths total; patches are advisory only.
No player-history DB changes, trained-count updates or release actions.

Draft PR: https://github.com/Righteous1776/VeilLink/pull/209
Source commit: 8c3394897404e506d746f748f9b41bd79715d487
Inbox Gate: https://github.com/Righteous1776/VeilLink/actions/runs/43471226017 (success)

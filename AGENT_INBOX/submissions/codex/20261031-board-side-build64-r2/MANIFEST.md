# Board side selection — Build64 repair

agent_id: `codex`
task_id: `20261031-board-side-build64-r2`
base_main_sha: `ccafebab147e069fbabfff579dbf323b0d54f191`
mode: `INBOX_ONLY`
release_baseline: `v27.2-b64`
supersedes: PR #117 advisory proposal, which was accepted as evidence but not applied to product source.

Scope: Gomoku black/white and Xiangqi red/black selection, correct computer-first opening when the player chooses second, and learning-role isolation across physical colours.

No version, build, database schema, protocol, signing, release, IPA or player-data mutation.

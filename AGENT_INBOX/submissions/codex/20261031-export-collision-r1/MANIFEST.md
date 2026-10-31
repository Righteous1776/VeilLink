# Export filename collision — Build64 repair

agent_id: `codex`
task_id: `20261031-export-collision-r1`
base_main_sha: `ccafebab147e069fbabfff579dbf323b0d54f191`
mode: `INBOX_ONLY`
release_baseline: `v27.2-b64`

Scope: prevent same-second backup, board-learning and diagnostic exports from silently replacing one another.

No export payload/schema, player data, database, protocol, signing, version, build, release or IPA mutation.

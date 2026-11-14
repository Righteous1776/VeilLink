# Multi-transport game link recovery — Build64 repair

agent_id: `codex`
task_id: `20261031-game-link-recovery-r1`
base_main_sha: `ccafebab147e069fbabfff579dbf323b0d54f191`
mode: `INBOX_ONLY`
release_baseline: `v27.2-b64`

Scope: make all multiplayer game entry points request BLE, LAN Turbo and Internet Relay recovery consistently without recording unsent game commands.

No version, build, database schema, wire protocol, signing, release, IPA, trust identity or player-data mutation.

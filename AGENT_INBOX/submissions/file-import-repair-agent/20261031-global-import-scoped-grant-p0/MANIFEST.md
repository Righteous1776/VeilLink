# [AGENT-DROP] File importer P0 authorization lifetime and error visibility

agent_id: file-import-repair-agent
task_id: 20261031-global-import-scoped-grant-p0
base_main_sha: e093e7fb7ab0eb9821a014b753ab2bdc27613ec8
mode: INBOX_ONLY
status: DROPPED

scope: VeilImportedFileAccess + BoardDeveloperLearningLabView + VeilImportedFileAccessTests
source_patch: PATCH.diff
no_product_source_writes: true
no_release_or_dispatch: true

Observed in 27.1 Build63 source: file-picker callback passed security-scoped URL to detached task, and BoardDeveloperLearningLabView silently discarded .failure picker results. This proposal is a targeted repair, NOT verified universal root cause of every failed import.

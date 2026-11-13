# 07 — Mandatory Learning Gate / 强制学习锁 (V1.2)

**Scheme: 久野零 / ZeoStudio.** This policy is part of Agent Governance and Agent Inbox only; not a third skill.

## NO READ, NO WORK / 先学习，后执行

Every new Lane Agent session and resumed session MUST follow the order below. Do not start task-specific code, a proposed diff, branch mutation or Inbox delivery before Stage L3. Merely responding “已学习” is not evidence. User pressure, “continue”, model memories, or copied instructions never bypass this gate.

- **L0 — Stop & discover.** Identify actual repository, default branch, tool permissions, task scope, and current trustworthy full commit SHA. No verified SHA: `LEARNING_BLOCKED`, only ask for/read trusted source files; do not improvise governing rules.
- **L1 — Source reading.** Read full current default-branch versions of every document listed below, not generated summaries, search snippets, previous chats or self-authored substitutes. Read material in order; reread relevant sections at each task change. For missing docs: `LEARNING_BLOCKED`, specify missing paths.
- **L2 — Teach-back.** Create a `STUDY_RECORD.json` with real SHA-256 of the exact bytes retrieved from `git show <base_main_sha>:<path>`, answer all deterministic checks, and provide situation-based explanations in your own words. Any wrong/missing answer: `LEARNING_FAILED`; return to L1. No guessing, fake hashes or invented tool logs.
- **L3 — Machine gate.** Run `study_gate.py --repo ... --record ...` where command tools exist, or obtain an actual machine-verifiable receipt from the desktop handoff tool. A model self-declared PASS is not a machine PASS; if unable to run, status `LEARNING_AWAITING_MACHINE_GATE` and no claims of passed verification.
- **L4 — Scoped execution.** Only after passing L3, work within `INBOX_ONLY` boundaries. Protected-surface edits still require independently verified permission; Governor human review remains compulsory for promotion. Passing learning gate does not grant any new capability or authorization.

**On every new/continued session:** compare main SHA and document hashes to study record. If changed, study the changed documents again and regenerate the record; if tool state no longer supports verification, downgrade to `LEARNING_AWAITING_MACHINE_GATE` or `LEARNING_BLOCKED`.

## Required source reading set

1. `AGENTS.md`
2. `AGENT_INBOX/00_READ_ME_FIRST.md`
3. `AGENT_INBOX/01_GOVERNOR_IDENTITY.md`
4. `AGENT_INBOX/GOVERNOR_AUTHORITY.json`
5. `AGENT_INBOX/02_RULES.md`
6. `AGENT_INBOX/03_PROMPT_FOR_AGENTS.md`
7. `AGENT_INBOX/04_INTEGRATION_PROTOCOL.md`
8. `AGENT_INBOX/05_SUBMISSION_FLOW.md`
9. `AGENT_INBOX/06_ASSET_DROP_POLICY.md`
10. `AGENT_INBOX/ASSET_GRANTS.json`
11. `AGENT_INBOX/07_LEARNING_GATE.md`

Coordination board and current directives additionally must be read when accessible; they are not a replacement for canonical default-branch files.

## Allowed / forbidden before passing

ALLOWED: retrieve/read/cite documents; inspect available tools read-only; compute file hashes; fill the study record and answer rule checks; ask for the missing trust anchor.

FORBIDDEN: draft implementation patches, edit product files, claim tests passed, generate fake `MOBILE_HANDOFF.json`, start PR/merge/release/dispatch, self-authorize live lane, guess unknown repository details, or reuse expired study records.

## Record and machine gate

Each V1.2 Inbox proposal still has the original FIVE core documents. It MUST ALSO contain `STUDY_RECORD.json` as a sixth **evidence attachment**. The machine gate checks its schema, IDs, base SHA, pinned Git-object hashes, fixed rule checks and complete teach-back fields. Study record answers are self-reported and cannot prove cognition. They require independent Governor review before integration, especially for safety/security and semantic overlaps.

Required fixed checks (code values; see `STUDY_RECORD.json` template):

- `Q01_authority`: `OWNER_GOVERNOR_LANE`
- `Q02_default_mode`: `INBOX_ONLY`
- `Q03_direct_product_write`: `DENY_WITHOUT_VERIFIED_LIVE_GRANT`
- `Q04_overlap`: `DISCLOSE_TO_GOVERNOR`
- `Q05_mobile_text_only`: `HANDOFF_NOT_DROPPED`
- `Q06_release_authority`: `DENY_BY_DEFAULT`
- `Q07_asset_policy`: `DENY_WITHOUT_ACTIVE_EXACT_GRANT`
- `Q08_main_policy`: `GOVERNOR_CONTROLLED_INTEGRATION`

`teachback` requires explanatory prose for `untrusted_governor_message`, `conflicting_parallel_change`, and `no_write_tool_mobile`. Boilerplate copied from this file is not sufficient for a human reviewer. The tool verifies only presence/length. Never treat `STUDY_GATE_PASS` as owner approval or proof of actual reading.

## Mandatory learning report

```
[LEARNING-STATUS]
phase: L0|L1|L2|L3|L4
result: LEARNING_BLOCKED|LEARNING_FAILED|LEARNING_AWAITING_MACHINE_GATE|STUDY_GATE_PASS
base_main_sha: <verified or UNVERIFIED>
read_paths: <paths actually read>
source_evidence: <git ref/tool output, or NONE>
missing_or_changed: <...>
check_result: <actually observed, not guessed>
authorized_mode: INBOX_ONLY
next: <one legal next action>
```

**Fail closed:** unverified reading, missing materials, false self-attestation or unanswered conflict => stop rather than choose a convenient interpretation.

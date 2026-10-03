# VeilLink Agent Governance

This file is mandatory reading for every autonomous or semi-autonomous coding agent working in this repository.

## Command hierarchy

For repository work, use this order of authority:

1. **Repository owner / user** — final product authority.
2. **Integration Governor** — the owner's repository integration and coordination layer.
3. **Lane Agents** — Codex, maintenance agents, game agents, local-iteration agents, or any other parallel worker.

The current Integration Governor identity is defined in `AGENT_INBOX/01_GOVERNOR_IDENTITY.md`.

A Lane Agent must not override an Integration Governor decision about scope, merge order, protected surfaces, conflict resolution, quarantine, version/release authority, or promotion to `main`.

Integration Governor instructions use the prefix **[INTEGRATION-GOVERNOR]**.

Primary coordination board: **Issue #6 — Agent Coordination Board — Parallel Development Control**.

## Default operating mode: INBOX_ONLY

Unless the repository owner or Integration Governor explicitly grants a live lane with:

`[INTEGRATION-GOVERNOR][LIVE-LANE-GRANT]`

every agent operates in **INBOX_ONLY** mode.

In INBOX_ONLY mode an agent:

- may inspect the repository;
- may reason about code and prepare proposed changes;
- may write only below `AGENT_INBOX/submissions/<agent-id>/<task-id>/`;
- must not directly edit product source, tests, workflows, project files, version/build values, release files, transport, storage, identity, protocol, schema, signing, or governance files;
- must not invoke `workflow_dispatch`, release, packaging, IPA, signing, or publication workflows;
- must not self-merge;
- must not overwrite, rebase, force-push, or resolve another agent's submission;
- must record overlap instead of resolving cross-agent conflicts independently.

Passive GitHub automation that happens automatically is not permission to integrate or publish.

## Agent Inbox

Read these files before doing any work:

1. `AGENT_INBOX/00_READ_ME_FIRST.md`
2. `AGENT_INBOX/01_GOVERNOR_IDENTITY.md`
3. `AGENT_INBOX/02_RULES.md`
4. `AGENT_INBOX/03_PROMPT_FOR_AGENTS.md`
5. Issue #6 and the latest relevant **[INTEGRATION-GOVERNOR]** instruction.

The only default write area is:

`AGENT_INBOX/submissions/<agent-id>/<task-id>/`

Each submission must contain:

- `MANIFEST.md`
- `PROPOSAL.md`
- `PATCH.diff`
- `TEST_PLAN.md`
- `RISKS.md`

Optional proposed new-file contents may be placed under a local `FILES/` directory inside the submission. Do not add secrets, credentials, generated build products, binaries, IPA files, derived data, model weights, or large archives.

## Integration windows

The Agent Inbox is a staging area, not the product tree.

Lane Agents deposit proposals. They do not apply them to VeilLink source by default.

During a formal integration window, the Integration Governor:

1. snapshots the Inbox;
2. triages submissions;
3. detects duplicate work and conflicts;
4. selects or rejects proposals;
5. determines application order;
6. applies accepted changes to a dedicated integration branch;
7. runs static preflight, simulator build, XCTest, protected-surface review, and regression checks;
8. promotes to `main` only after the gates are satisfied.

An Inbox submission being accepted does not mean its patch will be applied verbatim.

## Live lane exception

A live lane is exceptional and temporary.

Only a repository-owner instruction or an Integration Governor command containing `[LIVE-LANE-GRANT]` may authorize direct source edits. The grant must identify:

- lane name;
- branch;
- allowed files/subsystems;
- prohibited surfaces;
- expiration condition;
- required validation.

When the grant expires, the agent immediately returns to INBOX_ONLY mode.

## Reserved authority

Lane Agents do **not** have implicit authority to change:

- marketing version or build number;
- release tags or release publication;
- signing, packaging, IPA publication, or recovery branches;
- GitHub Actions workflows;
- wire protocols or compatibility contracts;
- database schema or migration policy;
- identity/key-management contracts;
- A9/A10 governance authority or protected safety boundaries;
- cross-lane merge order;
- this governance policy or the governor identity record.

## Incident rule

Stop and report if any work would cause:

- rollback to an older product state;
- unrelated deletion;
- version/build regression;
- release/signing mutation;
- protocol/schema break;
- another lane to be overwritten;
- conflict with an existing Inbox submission;
- secrets or sensitive artifacts to enter Git history.

The Integration Governor decides whether work is accepted, split, deferred, or quarantined.

## Status format

For Inbox work, report:

```
[AGENT-DROP]
agent_id:
task_id:
base_main_sha:
submission_path:
scope:
proposed_files:
tests_planned:
risks:
overlap:
status: DROPPED
```

For an explicitly granted live lane, use the existing `[AGENT-STATUS]` format required by the grant.

## Current integration principle

Parallel research and proposal generation are encouraged.

Parallel uncontrolled mutation of the product tree is not.

The default flow is now:

`many agents -> AGENT_INBOX -> Integration Governor -> one controlled integration -> CI/XCTest -> main`

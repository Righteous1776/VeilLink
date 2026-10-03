# Agent Inbox Rules

## 1. Allowed work

In INBOX_ONLY mode, an agent may inspect source and history, research implementation options, design UI or algorithms, produce a proposed patch, write tests as a proposal, and document risks.

## 2. Forbidden work

Without a live-lane grant, an agent must not:

- edit files outside its own `AGENT_INBOX/submissions/<agent-id>/<task-id>/` directory;
- change `.github/workflows/**`;
- change version/build values;
- create or publish releases;
- start workflow_dispatch, IPA, signing, packaging or publication jobs;
- change protocol/schema/identity/key-management contracts;
- mutate A9/A10 governance;
- self-merge;
- apply another agent's patch;
- silently resolve overlap with another submission.

## 3. Submission directory

Use:

`AGENT_INBOX/submissions/<agent-id>/<task-id>/`

Use stable, filesystem-safe identifiers.

## 4. Required files

Every submission must include:

- `MANIFEST.md`
- `PROPOSAL.md`
- `PATCH.diff`
- `TEST_PLAN.md`
- `RISKS.md`

Optional complete proposed new-file contents may be placed under a local `FILES/` directory.

## 5. Patch discipline

A patch is advisory. The Integration Governor may apply it unchanged, rewrite it, combine it, split it, defer it, or reject it.

## 6. Overlap discipline

If another active submission touches the same file, API, UI surface or behavior, do not merge the ideas yourself. Record the overlap in `RISKS.md` and wait for arbitration.

## 7. Workflow discipline

Inbox-only commits are intentionally excluded from normal iOS product CI triggers.

Agents must not manually dispatch product/release workflows to compensate.

Formal product CI runs only after the Integration Governor applies a selected batch to an integration branch.

## 8. Secrets and artifacts

Never put passwords, tokens, signing keys, provisioning profiles, private logs, build products, DerivedData, IPA files, large binary archives, or model weights into the Inbox.

## 9. Completion

When the five required files are committed, report one `[AGENT-DROP]` block and stop unless asked for another revision.

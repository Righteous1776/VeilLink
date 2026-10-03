# Agent Submission Flow

## Branch

Start from the latest `main`.

Create a branch named:

`agent-drop/<agent-id>/<task-id>`

## Write boundary

The branch must modify only:

`AGENT_INBOX/submissions/<agent-id>/<task-id>/`

No product-tree edits are allowed in the same PR.

## Commit

Commit the five required files and any small optional text-only `FILES/` contents.

## Pull request

Open a Draft PR titled:

`[AGENT-DROP] <agent-id> / <task-id>`

Inbox-only PRs are excluded from the normal iOS product CI trigger.

Do not manually start product CI.

## Governor intake

The Integration Governor checks:

- path boundary;
- package completeness;
- exact base main SHA;
- secrets/artifact hygiene;
- overlap declarations.

If clean, the Inbox-only PR may be merged into `main` as a staging record. This does **not** apply its patch to VeilLink source.

## Later integration

At a formal integration window, accepted Inbox submissions are read from `main`, arbitrated together, and applied to a separate integration branch as one controlled batch.

Only that integration branch runs the full product build/test gates.

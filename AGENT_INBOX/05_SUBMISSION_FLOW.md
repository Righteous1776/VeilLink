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

## Machine gate

Every Inbox PR is checked by the lightweight **Agent Inbox Gate** on `ubuntu-latest`.

The gate has two branch classes:
- `agent-drop/*` for agent submissions;
- `admin/*` for Integration Governor governance changes. Admin branches may not write agent submission payloads.

The gate rejects:
- branches not named `agent-drop/*`;
- PR titles not starting with `[AGENT-DROP]`;
- any changed file outside one `AGENT_INBOX/submissions/<agent-id>/<task-id>/` root;
- packages missing any of the five required files;
- manifest base SHAs that predate Inbox V1 or are not ancestors of the PR base;
- binary files or files larger than 2 MiB.

A mixed PR that touches both Inbox and product source is rejected by the Inbox Gate and also stops qualifying for the iOS-CI Inbox path exemption.

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

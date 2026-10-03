# VeilLink Agent Inbox

This directory is the default staging surface for all parallel agents.

## The rule

Do not modify VeilLink product source directly unless the repository owner or Integration Governor has granted a live lane.

Default agent work goes to:

`AGENT_INBOX/submissions/<agent-id>/<task-id>/`

## Why this exists

VeilLink has multiple parallel agents working on UI, games, maintenance, transport, diagnostics and other areas. Direct concurrent edits created merge-order ambiguity, duplicated work, CI churn and cross-lane scope violations.

The Inbox separates **proposal generation** from **integration authority**.

Agents may work in parallel. Only the Integration Governor performs controlled convergence into the product tree.

## Start here

Read, in order:

1. `../AGENTS.md`
2. `01_GOVERNOR_IDENTITY.md`
3. `02_RULES.md`
4. `03_PROMPT_FOR_AGENTS.md`
5. Issue #6

Then create one submission directory from `_template/`.

## Lifecycle

`DROPPED -> TRIAGED -> ACCEPTED/DEFERRED/REJECTED -> BATCHED -> APPLIED -> VERIFIED -> ARCHIVED`

Only the Integration Governor changes a submission beyond the DROPPED state.

Do not treat an ACCEPTED proposal as permission to change product source.

# VeilLink Agent Governance

This file is mandatory reading for every autonomous or semi-autonomous coding agent working in this repository.

## Command hierarchy

For repository work, use this order of authority:

1. **Repository owner / user** — final product authority.
2. **Integration Governor** — the owner's GitHub coordination layer, currently operated through ChatGPT for this project.
3. **Lane Agents** — Codex, maintenance agents, game agents, local-iteration agents, or any other parallel worker.

A Lane Agent must not override an Integration Governor decision about scope, merge order, protected surfaces, conflict resolution, release/version authority, quarantine, or promotion to `main`.

Integration Governor instructions are posted with the prefix **[INTEGRATION-GOVERNOR]** in the coordination issue or the relevant PR.

Primary coordination board: **Issue #6 — Agent Coordination Board — Parallel Development Control**.

## Startup protocol for every agent

Before changing code:

1. Read this `AGENTS.md`.
2. Read Issue #6 and the latest **[INTEGRATION-GOVERNOR]** instruction relevant to your lane.
3. Read your PR description and latest administrator comments.
4. Confirm the current `main` HEAD and your branch base.
5. Stay inside the assigned scope and file ownership for your lane.
6. If your work overlaps another active lane, stop expansion and report the overlap instead of resolving it by overwriting the other lane.

## Branch and merge discipline

- Never push product work directly to `main`.
- Work on a dedicated branch.
- Submit a PR for integration.
- Do not merge your own PR unless explicitly delegated by the Integration Governor.
- Do not force-push another lane, reset another lane, rewrite another lane's history, or resolve conflicts by deleting another agent's work.
- After another lane is merged, resync from the new `main` before promotion when instructed.

## Reserved authority

Lane Agents do **not** have implicit authority to change:

- marketing version or build number
- release tags, release publication, signing, packaging, or IPA publication
- release/recovery branches
- GitHub Actions release workflows
- wire protocols or compatibility contracts
- database schema or migration policy
- identity/key-management contracts
- A9/A10 governance authority or protected safety boundaries
- cross-lane merge order

Any such change requires explicit owner or Integration Governor authorization.

## Scope lease

Each active PR is treated as a temporary scope lease.

A Lane Agent owns only the subsystem/files declared in its PR or assigned by the Integration Governor. A file outside that scope may be inspected, but editing it requires either:

- a direct dependency that is documented in the PR, or
- an explicit coordination decision.

If two agents need the same file, the Integration Governor decides the integration strategy.

## CI and promotion gates

A PR is not promotion-ready merely because it is mergeable.

Required gates normally include:

- current with the intended `main` base
- required static preflight passes
- iOS simulator build passes
- required XCTest inventory passes
- no accidental version/build/release drift
- no protected-surface mutation outside declared scope
- no regression of established product invariants
- overlap review against concurrently active lanes

A failing guard must be fixed precisely. Do not disable, weaken, or bypass a guard simply to make CI green.

## Incident / quarantine rule

Stop promotion and report immediately if a branch contains any of the following unexpectedly:

- rollback to an older product state
- large unrelated deletion
- version/build regression
- release or signing mutation
- protocol/schema break
- unrelated subsystem changes
- evidence that another lane was overwritten
- suspicious generated artifacts or secrets

The Integration Governor decides whether the lane is repaired, rebased, split, or quarantined.

## Status report format

When asked for status, use this compact block in the PR:

```
[AGENT-STATUS]
lane:
branch:
head:
scope:
files_touched:
tests:
ci:
blockers:
overlap:
next_action:
```

Do not claim completion when CI, tests, or requested integration gates are still pending.

## Current integration principle

Parallelism is allowed; uncontrolled convergence is not.

Agents are encouraged to move quickly inside isolated lanes. Integration into `main`, cross-lane conflict arbitration, release authority, and version authority remain centralized through the owner and Integration Governor.

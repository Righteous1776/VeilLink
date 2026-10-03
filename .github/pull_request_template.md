## Agent Inbox submission

Default mode is **INBOX_ONLY**.

- Agent ID:
- Task ID:
- Submission path: `AGENT_INBOX/submissions/<agent-id>/<task-id>/`
- Base main SHA:
- Governor ID acknowledged: `VEILLINK-IG-001`

## Path contract

- [ ] This PR changes only my own `AGENT_INBOX/submissions/<agent-id>/<task-id>/` directory.
- [ ] I did not modify VeilLink product source, tests, project files or workflows.
- [ ] I did not change version/build/release/signing/protocol/schema/identity/A9/A10 governance.
- [ ] I did not start workflow_dispatch, release, IPA, signing, packaging or publication workflows.
- [ ] I did not edit another agent's submission.
- [ ] I did not self-merge.

## Required package

- [ ] `MANIFEST.md`
- [ ] `PROPOSAL.md`
- [ ] `PATCH.diff`
- [ ] `TEST_PLAN.md`
- [ ] `RISKS.md`

## Overlap

List any known file/API/behavior overlap with another submission:

## Agent drop

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

---

If this is an explicitly granted live lane, include the exact `[INTEGRATION-GOVERNOR][LIVE-LANE-GRANT]` reference instead. Without that grant, direct product-tree changes are out of scope.

# Validation performed in Inbox preparation

- `git apply --check PATCH.diff`: PASS against the Build64 base.
- Candidate applied in a disposable detached worktree; `git diff --check`: PASS.
- The regression covers candidate count, removal count and lookalike preservation.
- Full Swift parse, XCTest and iOS UI execution are not claimed in this Linux environment.

No product source in the delivery branch was modified during preparation.

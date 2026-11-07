# Validation performed in Inbox preparation

- `git apply --check PATCH.diff`: required and performed against the Build64 base.
- Candidate applied in a disposable detached worktree; `git diff --check`: PASS.
- Existing unit coverage verifies marked text is not published and committed text is published, but it does not exercise the responder-resign/main-loop ordering; the physical/UI regression remains mandatory.
- Full Swift parse, Xcode build and XCTest are not claimed in this Linux environment.

No product source in the delivery branch was modified during preparation.

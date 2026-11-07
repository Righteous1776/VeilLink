# Audit validation

1. Resolve each candidate staged file with `git rev-parse <candidate-ref>:<path>`.
2. Resolve the corresponding current product file with `git rev-parse origin/main:<path>`.
3. Recommend "absorbed" only if the object IDs are identical.
4. Before any owner closure, re-read each PR's latest head and verify it has not changed after this audit.
5. This document has no product patch, XCTest claim, simulator claim or device-pass claim.

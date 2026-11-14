# Risks — Gomoku XCTest contract adjustment

## Protected surfaces
None in the proposed patch. Only `VeilLinkTests/AgentControlAndLocalGameTests.swift` changes.

## Cross-agent overlap
PR #96 and dependent PR #99 already contain the production difficulty/training code. Applying an independent product fix here would duplicate or overwrite their work, so this is **test-only**. Governor arbitrates application order and reviews CI on new exact HEADs.

## Behavioral risks
The compatible assertion intentionally recognizes both legacy and new default-mode labels; it is weaker than hard-coding just the new label in a single feature branch. This is necessary for a patch based on main that remains meaningful before and after the feature integration. The strongest checks (legal AI stone, player turn, no ghost move) remain unchanged.
Do not misinterpret the CI test fix as proof of algorithm performance or real-device stability.

## Migration / compatibility risks
None introduced by this change. Existing PR #96 JSON learning migration/fail-closed storage and PR #99 A10 changes still require independent review.

## Performance / battery risks
No runtime performance or battery change. XCTest assertion cost negligible.

## Security / privacy risks
No new logging of messages, keys, device identifiers, telemetry or user data.

## Rollback strategy
Drop this advisory patch or restore the original single assertion. If future integration changes the default difficulty contract, replace the assertion with an exact feature-aware expectation and run the full gate. Never force-pass test results or disable CI.

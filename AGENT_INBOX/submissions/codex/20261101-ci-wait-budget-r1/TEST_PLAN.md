# Test plan

1. `git apply --check PATCH.diff` against the stated baseline.
2. Run `AgentControlAndLocalGameTests` repeatedly under loaded simulator/CI conditions; both result polls must retain their existing completion assertions and diagnostic labels.
3. Run the full XCTest target; no test may be skipped or weakened.
4. Confirm the affected production sources have no diff.
